# 04 - Fine-Tuning

> A distributed LoRA fine-tune of `Qwen2.5-7B-Instruct` on the `gretelai/synthetic_text_to_sql` dataset. It runs on both H100 nodes of the Soperator cluster, through Slurm, with `Axolotl` in a container and plain data parallelism (DDP) over Ethernet.

---

# Summary

This is a summary of the file, with a link to each main section.

* [Description](#description) - what the task is, how the Soperator cluster is built, and the skill we teach the model: writing SQL from an English question and the tables of a database.
* [Strategy and why](#strategy-and-why) - the plan in four parts (train, save, serve and test), and the reasons behind the main choices.
* [The tools](#the-tools) - the software stack from top to bottom, and what each tool does in this job (Hugging Face Transformers/PEFT/Accelerate/Pytorch/Tokenizer, Pexis & Enroot, Axolotl, LoRA, DDP, NCCL).
* [Preparation](#preparation) - everything from the dataset to the finished fine-tune and its first test.
  * [Downloading the dataset](#downloading-the-dataset) - get `gretelai/synthetic_text_to_sql` to the laptop, pinned to one commit. - Install Hugging Face CLI + Download Dataset (Sunthetic SQL-To-Text)
  * [Checking the dataset](#checking-the-dataset) - three phases of checks and preparation, run on the laptop before any GPU time is spent.
    * [Phase 1: Data validation](#phase-1-data-validation) - is the data fit to use? - Missing or Blank value + Duplicate Data + Overlap between training & test datasets.
    * [Phase 2: Data checking for the Axolotl settings](#phase-2-data-checking-for-the-axolotl-settings) - the facts that set the values in the Axolotl file. - Checl Data structure + Length of texts.
    * [Phase 3: Data preparation](#phase-3-data-preparation) - get the data ready for the training and for the final test. - Handel Data Issues + Convert Training Training Data (System, User, Assistent For Each Row) + Converting Training Data (System, User, Assistent For Each Row) + Check the token length for the converted data.
  * [Uploading the data](#uploading-the-data) - copy the files to `/mnt/data` and prove that both 
  * [Checking flash attention](#checking-flash-attention) - the container has no `flash_attn` package, and the PyTorch `sdpa` kernel runs instead.
  * [The Axolotl configuration](#the-axolotl-configuration) - the final YAML file, with a short comment next to each setting.
  * [Running the smoke test](#running-the-smoke-test) - 20 steps on one worker to check the config, the memory and the GPU.
  * [Testing on two nodes](#testing-on-two-nodes) - both GPUs train as one job, and the step time is 3.19 s against 3.17 s on one node.
  * [Updating the configuration](#updating-the-configuration) - the tests confirm the batch and attention settings.
  * [Running the fine-tuning](#running-the-fine-tuning) - the real run on both nodes: 282 steps in 13 minutes, and the validation loss falls from 1.214 to 0.1773.
  * [Testing the tuned model](#testing-the-tuned-model) - the same 20 test questions go to the original and the tuned model. The tuned model answers with SQL only, and 8 of 20 answers match the correct SQL exactly.

---

# Description

This section holds everything needed to fine-tune a general-purpose language model, `Qwen2.5-7B-Instruct`, on a Slurm cluster that runs on Kubernetes and is provisioned with Soperator. For how the cluster is built, see [03-Provision](/03-Provision/README.md).

The Nebius Demo Day task is to run a distributed training or fine-tuning job on a Nebius `Soperator` cluster, using the latest Soperator release available at the time, `soperator-v4.1.13-2`. The task has two halves. [03-Provision](/03-Provision/README.md) covers the first half, which is building the infrastructure. This section covers the second half, which is running the fine-tuning job.

The section and the associated activity also lays the ground for the next tasks: serving the tuned model on the same Kubernetes cluster (task 2) and reaching GPU utilization above 80% (task 4). Both are kept in mind in the design of this section.

In this section we will fine-tune a general-purpose model one narrow skill: translating English into SQL. The tuned model receives the tables of a database and a question in English, and it writes the SQL query. The base model already knows some SQL. Fine-tuning makes it more accurate and more consistent on this one job.

The infrastructure is covered in detail in [03-Provision](/03-Provision/README.md). In short, it is a managed Kubernetes cluster on Nebius, with Slurm deployed on top by Soperator. It has these node groups:
- **System:** four nodes that hold the system services. The Slurm login pod also runs here.
- **Controller:** one node for the Slurm controller.
- **NFS:** one node for the NFS server.
- **Workers:** two single-GPU nodes, `worker-0` and `worker-1`, with one H100 80 GB each.

Two shared filesystems are mounted on the cluster nodes. The first is the **jail**, a 1 TiB filesystem mounted on the four system nodes, the controller node and the two workers. It is mounted at `/mnt/jail` inside the Slurm pods, and it acts as the shared root filesystem of the Slurm cluster. The operating system, the installed packages and the Slurm tools live there, so the login pod, the controller and both workers always see the same software. The second is the **jail submount** `data`, also 1 TiB, mounted on the same nodes at `/mnt/data`. It holds the working data of the job: the dataset, the model cache, the checkpoints, the logs and the final adapter. Both workers read and write the same files in `/mnt/data`, so nothing needs to be copied between nodes.

The cluster has no InfiniBand. The two workers talk to each other over normal Ethernet, which was measured at roughly 3 GB/s. This limit shapes almost every choice in this section.

The section explains the strategy and the reasons behind it, and the tools that are used. It holds the configuration files, with a detailed explanation of each chosen setting, and the scripts needed to run the job. It ends with a step-by-step guide that can be followed until the fine-tuned model exists and has been tested.

Any issue met during the implementation, the configuration or the testing is recorded. A small issue is described in this file. A bigger one has its own folder, and a link is given here. For the full list, see [07-Finding-&-Troubleshootings](/07-Finding-&-Troubleshootings/README.md).

---

# Strategy and why

## The strategy in one paragraph

The strategy is to take a general-purpose model, `Qwen2.5-7B-Instruct`, and teach it one narrow skill: writing SQL from an English question and the tables of a database. The skill is taught with a public dataset, `gretelai/synthetic_text_to_sql`. Each example in it holds the tables, the question and the correct SQL.

The method is **LoRA** in bf16. LoRA freezes the original model and trains only a small add-on, called the adapter. **Axolotl** runs the training from a pinned container, which Slurm starts on each worker through Pyxis. Both workers train the same model on different slices of the data (**DDP**, one process per node), and only the small adapter gradients cross the Ethernet link. All files live on the shared `/mnt/data` filesystem, so both nodes see the same data, cache and checkpoints.

Two limits shape the plan. The cluster has only two GPUs, one on each worker, and it has no InfiniBand. LoRA keeps the data exchanged between the GPUs small enough for normal Ethernet. Training and serving share the same two GPUs, so they run one after the other. When training ends, the adapter is saved, the GPUs are released, and the tuned model is served on the same worker nodes. A part of the dataset is kept aside and never used in training. It is then used to test the original model and the tuned model on the same questions.

The strategy therefore has four parts, all on the same two worker nodes: train, save, serve and test.
- **Train.** The base model is `Qwen/Qwen2.5-7B-Instruct`. The training data is `gretelai/synthetic_text_to_sql`, which has about 100,000 training examples. Each example has the tables of a database, a question in English and the correct SQL query. LoRA keeps memory use low, and it keeps the data that the two GPUs must exchange small. This matters because the nodes are connected by normal Ethernet and not by InfiniBand. Axolotl runs the job in a pinned container on each worker. Each node trains on its own slice of the data, and only the adapter gradients cross the network.
- **Save.** The result of training is the adapter. It is a few hundred MB, not a new 15 GB model. The dataset, the model cache, the checkpoints and the adapter all live on `/mnt/data`. Both nodes see the same files, and the next parts find the adapter in a known place.
- **Serve.** The tuned model is served on the same Slurm worker nodes. Training finishes first and releases the GPUs. Serving then runs the base model together with the adapter. Training and serving never run at the same time, because there are only two GPUs.
- **Test.** The part of the dataset that was kept aside is used for testing. The same questions go to the original model and to the tuned model, and the two answers are compared. The inputs are identical, so the difference comes from the fine-tuning and nothing else.

## Key decisions

| Decision | Choice | Why |
|---|---|---|
| Method | **LoRA**, bf16, no quantization | An H100 has 80 GB. A 7B model in bf16 is about 15 GB, so QLoRA is not needed. LoRA keeps the trainable part small. |
| Parallelism | Plain **DDP**, one process per node | Each GPU holds the full model. The only network traffic is the gradient average. Sharding (FSDP, ZeRO-3) would move model weights over Ethernet at every step. |
| Framework | **Axolotl**, driven by one YAML file | The run is easy to repeat, review and keep in Git. Nebius also uses Axolotl in its own fine-tuning tutorial. |
| Launcher | **torchrun**, started by `srun` on each node | This is the pattern in the Axolotl multi-node docs. The docs have no Slurm guide, so the Slurm wrapper is written as part of this work. |
| Container | **axolotl/axolotl:main-20261013-py3.12-cu130-2.13.0** | A dated tag, so both nodes and every rerun get the same software. A test run confirmed that it works: H100 visible, torch 2.13.0+cu130, CUDA available, Axolotl CLI present. |
| Base model | **Qwen/Qwen2.5-7B-Instruct** | Apache 2.0 and not gated, so no Hugging Face token is needed. Small enough for one H100, and strong enough to show a clear before-and-after difference. |
| Dataset | **gretelai/synthetic_text_to_sql** | Apache 2.0 and not gated. It has 100,000 train rows and 5,851 test rows. Each row has a question, the table definitions and the correct SQL. |
| Storage | Everything under **/mnt/data** | It is the shared filesystem. The data, the Hugging Face cache, the checkpoints and the final adapter are visible from both nodes. |

## Why LoRA fits a cluster without InfiniBand

In data-parallel training, the GPUs must share their gradients after every optimizer step. With full fine-tuning, that is the size of the model: gigabytes per step. Over 3 GB/s Ethernet, the GPUs would spend most of their time waiting.

LoRA freezes the original weights and trains two thin matrices next to each weight matrix. Only the gradients of those thin matrices are shared. That is tens of megabytes per step, not gigabytes. The network stops being the bottleneck.

Gradient accumulation helps too. In DDP, the gradient sync happens once per optimizer step, not once per micro-batch. A higher accumulation value means less network traffic for each training sample.

## Why DDP and not FSDP or DeepSpeed ZeRO

FSDP and ZeRO-3 split the model, the gradients and the optimizer state across GPUs. This saves memory. The price is that the weights are gathered over the network in every layer, at every step. That is gigabytes of traffic, which is too much for this Ethernet link.

Memory saving is not required as the model fits perfectly on one GPU. So sharding would solve a problem we do not have, and it would create a network problem we cannot afford.

---

# The tools

## The stack from top to bottom

| Layer | Tool | What it does here |
|---|---|---|
| Scheduler | Slurm, run by Soperator | Starts one task on each node and gives each task its GPU. |
| Container runtime | Pyxis and Enroot | Lets `srun --container-image` run a Docker image on a Slurm node, without Docker. |
| Training tool | Axolotl | Reads one YAML file and runs the whole fine-tune. |
| Launcher | `torchrun` | Starts the training process on each node and connects them. |
| Training library | Hugging Face Transformers | Loads the model and the tokenizer. Runs the training loop. |
| Adapter library | PEFT | Adds the LoRA layers to the model. |
| Multi-GPU helper | Accelerate | Handles the data-parallel setup inside the training loop. |
| Math engine | PyTorch | Runs the computation on the GPU. |
| GPU communication | NCCL | Moves the gradients between the two GPUs. Here it uses Ethernet sockets. |
| Attention kernel | Flash attention | A faster and leaner way to compute attention. |
| Measurement | `nvidia-smi` | Records GPU utilization and memory. |

## Pyxis and Enroot

Slurm normally runs programs that are installed on the node. The training job needs a specific software stack instead: Axolotl, PyTorch, CUDA libraries and their exact versions. This stack is packaged as a container image, and two tools let Slurm run it.
- **Enroot** is a container runtime built for HPC clusters. It takes a standard Docker image, pulls it from a registry such as Docker Hub, unpacks it into a plain directory, and starts a process inside it. It needs no Docker daemon and no root rights, which suits a shared Slurm cluster.
- **Pyxis** is a Slurm plugin that connects Slurm to Enroot. It adds container flags to `srun`, for example `--container-image`. When a job is started with this flag, Pyxis asks Enroot to prepare the image on each allocated node, and Slurm then runs the task inside it. The task still gets its own CPUs and its GPU from Slurm, as any other job does.

For this job, the flag points to the pinned Axolotl image. Each worker pulls the same image tag and runs the training task inside it. This gives both nodes identical software, with nothing installed by hand on the workers.

The image is about 8.7 GB, so the first pull on each node takes time. Later runs reuse the unpacked copy, so they start faster. Soperator sets Pyxis up with its own importer script, `pyxis_caching_importer.sh`, which is part of the cluster configuration. Where the image cache is stored, and whether it can be moved to `/mnt/data`, is checked in the preparation step.

## Axolotl

Fine-tuning a model with plain PyTorch needs a long script: load the model, load and tokenize the data, add the adapter layers, set up the optimizer, run the training loop, evaluate, save. Axolotl replaces this script with a single YAML file.

The YAML file describes the whole run: the base model, the dataset and its format, the LoRA settings and the training settings. Axolotl reads it and does the rest. It downloads the model, prepares and tokenizes the data, builds the LoRA model, trains, evaluates and saves the result.

The YAML file brings repeatability. The file is the full description of a run. A change in the setup is a change in one line, and its effect is easy to compare with the previous run. Both nodes read the same file, which keeps their setup identical.

## Hugging Face Transformers, PEFT, Accelerate and PyTorch

Axolotl does not train the model by itself. It drives four libraries, and each has one job.
- **PyTorch** runs the computation on the GPU. Every other library here is built on it.
- **Hugging Face Transformers** provides the model, the tokenizer and the training loop.
- **PEFT** adds the LoRA layers to the model and keeps track of which weights are trainable.
- **Accelerate** handles the multi-GPU part, so the same training code runs on one GPU or on several.

These libraries are never called directly in this work. Axolotl calls them, and the YAML file controls how. They are listed here because their names appear in logs and error messages, and knowing the role of each one makes those messages easier to read.

## LoRA

LoRA stands for low-rank adaptation. It is a way to fine-tune a large model without changing the whole model.

A language model is made of large weight matrices. Full fine-tuning changes all of them. Training then needs more than the weights: it also stores a gradient for each value, and the optimizer keeps extra state for each value. With the usual mixed-precision setup, this is about 16 bytes per value, which is roughly 110 to 120 GB for a 7B model before activations. That is more than one 80 GB GPU holds. The weights alone are only about 15 GB.

LoRA keeps every original weight frozen, so no gradients or optimizer state are kept for them. Next to each large matrix, it adds two thin matrices, called A and B. The product of A and B is a small correction that is added to the output of the frozen matrix. Only A and B are trained. The frozen weights and the activations fit on one GPU with room to spare.

The **rank** (`lora_r`) is the width of the thin matrices. A higher rank can learn more and costs more memory. With the starting rank of 16, the trainable part is in the tens of millions of values, against 7 billion in the full model. The exact count appears in the training log.

The saved result is only A and B, called the **adapter**. It is much smaller than the base model. To use it, the base model is loaded first, and the adapter is applied on top. This is why the same base model can serve both the original and the tuned version in the comparison step.

LoRA also keeps the network traffic small. In data-parallel training, the GPUs exchange the gradients of the trained values after every optimizer step. With full fine-tuning, that is a gradient for every weight in the model. With LoRA, only A and B have gradients, so the traffic is a small fraction of the model size. This is what makes LoRA suitable for GPUs that are connected by Ethernet and not by InfiniBand.


## torchrun and the multi-node launch

A training job on two nodes needs one training process on each node, and the processes need to find each other. `torchrun`, the launcher of PyTorch, handles both.

`torchrun` is started once on each node. Every copy contacts a **rendezvous** address, which is the IP and port of the first node. When all copies have joined, `torchrun` gives each process its rank and the size of the group, and training starts. In this job there are two nodes and one GPU per node, so there are two processes in total.

The launch command from the Axolotl multi-node docs is:

```bash
axolotl train config.yaml --launcher torchrun -- \
  --nnodes $num_nodes --nproc_per_node $gpu_per_node \
  --rdzv_id $rdzv_id --rdzv_backend c10d \
  --rdzv_endpoint "$head_node_ip:$head_node_port"
```

Here `num_nodes` is 2 and `gpu_per_node` is 1. The `rdzv_id` is a unique name for the job, and `c10d` is the PyTorch backend that handles the rendezvous. The docs state that every machine needs the same Axolotl version and the same config file, and that the head node must be reachable from the other node. The pinned image and the shared `/mnt/data` cover the first two points. The cluster network covers the third.

The Axolotl docs have no guide for Slurm, so the Slurm script that starts one task per node and picks the first node as the rendezvous host is written for this work. It is covered in a later part of this section.

Source: [Axolotl multi-node docs](https://docs.axolotl.ai/docs/multi-node.html)

## NCCL

NCCL is the NVIDIA library that moves data between GPUs. After each optimizer step, it averages the adapter gradients of the two GPUs, so both models stay identical.

NCCL picks its transport at startup. With InfiniBand, it uses the InfiniBand network. This cluster has none, so NCCL uses normal TCP sockets over the Ethernet interface. The NCCL test on this cluster, covered in [03-Provision](/03-Provision/README.md), showed `NET/Socket` as the transport. The first training run confirms the same.

---

# Preparation

We need to prepare and get some answers before we move forward. What we are going to do is:

1. **Download the dataset** to a laptop.
2. **Check and prepare the dataset**, to find out what it looks like, if it is clean, if the test file leaks into the training file, and how long the examples are. Then it is converted into the format that Axolotl needs.
3. **Upload the data** to the cluster, and verify that the copy is identical and that both workers can see it.
4. **Write the Axolotl configuration file**, with every setting confirmed by the answers from the steps above.

Each part answers a question that must be settled before the first training run, because a mistake in the data or in the configuration is only found at the end. The checks are cheap. They run in seconds, mostly on the laptop, and they either set a value in the Axolotl file or protect the final comparison of the original and the tuned model.

---

## Downloading the dataset

The dataset is `gretelai/synthetic_text_to_sql`, published on Hugging Face under the Apache 2.0 license. It is small: the whole repository is 34.3 MB. It is downloaded once to a laptop, checked there, and then uploaded to the shared `/mnt/data` filesystem of the cluster. Every run then reads the same files, so the data cannot change between runs.

The repository holds these files:

| File | Size | Used here |
|---|---|---|
| `synthetic_text_to_sql_train.snappy.parquet` | 32.4 MB | Yes. The training data, about 100,000 rows. |
| `synthetic_text_to_sql_test.snappy.parquet` | 1.9 MB | Yes. The test data, about 5,850 rows. |
| `README.md` | 8.19 kB | Yes. The dataset card, kept as a record. |
| Four `.txt` files (`bmc2_llm_judge_example_1.txt`, `bmc2_llm_judge_example_2.txt`, `dalle_prompt.txt`, `llm_as_a_judge_rubric.txt`) | about 8 kB | No. They describe how the dataset was generated and judged. |

The only thing needed on the laptop before the download starts is a dedicated folder for the dataset. It sits outside the Git repository, for example `dataset_synthetic_text_to_sql` in the Downloads folder. All the commands in the checking and preparation sections run inside this folder.

```bash
mkdir -p ~/Downloads/dataset_synthetic_text_to_sql
cd ~/Downloads/dataset_synthetic_text_to_sql
export DATA_DIR=~/Downloads/dataset_synthetic_text_to_sql
```

![image1](/04-Fine-Tune/Images/image1.png)

Expected: no output. The prompt shows the new folder.

### Step 1: Install the Hugging Face CLI

The CLI is the `hf` command. It downloads files from the Hub. On macOS, Homebrew installs it:

```bash
brew install hf
hf version
```

![image2](/04-Fine-Tune/Images/image2.png)

Expected: `hf version` prints the version. Without Homebrew, `pip install -U huggingface_hub` installs the same CLI.

### Step 2: Download the dataset to the laptop

This downloads the whole repository into the current folder.

The command pins the download to one commit with `--revision`. The hash below is the latest commit that the Hugging Face page showed on 14 October 2026. A pinned commit means that a later change to the dataset on the Hub cannot change what is downloaded.

```bash
hf download gretelai/synthetic_text_to_sql \
  --repo-type dataset \
  --revision 740ab236e64503fba51be1101df7a1be83bf455d \
  --local-dir .
ls -lh
```

![image3](/04-Fine-Tune/Images/image3.png)

Expected: a progress bar, then the path of the folder on the last line. A warning about unauthenticated requests can appear. It is harmless for a public dataset. The download also creates a hidden `.cache` folder inside the dataset folder.

---

## Checking the dataset

The dataset has two files: the train data and the test data. The train data is used to train the model. The test data is used to test how well the model learned.

Before we write the Axolotl file, we work with the dataset in three phases:

1. **Data validation.** Is the data fit to use? The dataset is public and widely used, so we do not expect problems. The validation is run once, as a precaution, and the results are recorded.
2. **Data checking for the Axolotl settings.** Several settings in the Axolotl file depend on how the dataset looks: which column is the question, which is the answer, how many rows there are, and how long the examples are. This phase finds these facts.
3. **Data preparation.** This phase gets the dataset ready for the training and for the final test.
   - **3a. Handle the issues found in the validation.** Any issue found in the data validation is handled here.
   - **3b. Convert the training data.** Axolotl reads each training example as a short conversation: a question from the user and an answer from the model. Our files store the question, the tables and the answer in separate columns. A small script puts them together into the conversation format.
   - **3c. Convert the test data.** After the training, we send the test questions to the original model and to the tuned model, and we compare their answers. The tuned model learned from conversations in one exact format, so the test questions must be sent in that same format. The same conversion is applied to the cleaned test data.
   - **3d. Check the converted training data.** The model reads tokens and not letters, and it expects every conversation in its own format. This check measures the real length of the examples in tokens, and confirms that the format and the end-of-answer marker are the ones that the training expects.

The phases are listed in the order of the work. The facts that phase 2 finds, for example the names of the columns, are needed to prepare the data in phase 3.

Why do we do all this before the training? If the data or a setting is wrong, the training is useless and the trained model cannot be trusted. The problem is that we would not know until the end, after the training has finished (the GPUs were used for nothing) and the model is tested. The checks are cheap. They run on the downloaded files on the laptop, with short Python scripts, in a few seconds.

---

### Preparing the Python virtual environment

The checks and the data preparation are short Python scripts. They need four extra Python packages:

- **`pandas`** reads the data and works with it as a table.
- **`pyarrow`** lets pandas open Parquet files, which is the format of our dataset.
- **`transformers`** loads the tokenizer of the model. The tokenizer cuts text into tokens, which are the small pieces of text that the model reads. It is used in the token check.
- **`jinja2`** builds the text of a conversation from the chat template of the model. `transformers` needs it for this, and it does not always install it by itself.

These packages are installed in a **virtual environment** (`venv`) and not in the Python of the laptop. It is a private folder with its own Python packages, so nothing is installed into the system Python.

**First time only.** These commands create the environment and install the packages:

```bash
python3 -m venv ~/nebius-demoday/.venv-data
source ~/nebius-demoday/.venv-data/bin/activate
pip install pandas pyarrow transformers jinja2
```

To confirm that the installation worked:

```bash
python3 -c "
from importlib.metadata import version
for p in ('pandas', 'pyarrow', 'transformers', 'jinja2'):
    print(p, version(p))"
```

![image4](/04-Fine-Tune/Images/image4.png)

Expected: four lines, one for each package, with its version number.

> [!NOTE]
> **Every time a new terminal window is opened.** The virtual environment lasts only as long as the terminal window, and the scripts read their files from the current folder. In a new window, these two commands start the environment again and move to the dataset folder. The prompt then begins with `(.venv-data)`:
>
> ```bash
> source ~/nebius-demoday/.venv-data/bin/activate
> export DATA_DIR=~/Downloads/dataset_synthetic_text_to_sql
> cd "$DATA_DIR"
> ```
>
> The environment is created once and reused. Only these two lines are repeated.

---

### Phase 1: Data validation

The validation answers one question: is there anything in the data that would make the training or the final comparison wrong? Three things are checked. 

Each row in the dataset is one example. It holds three pieces of information that matter for the training, each in its own column:
- `sql_prompt`: the question, in English. For example: "What is the total volume of timber sold by each salesperson, sorted by salesperson?"
- `sql_context`: the tables of a small database that the question is about.
- `sql`: the correct SQL query that answers the question.

The other columns only describe the example, such as its topic and its level of difficulty. The validation looks at the three columns above, because they are the ones the model is trained on.

- **[Validation 1] Missing and blank values.** Every row must have data in every column that we use. A missing value is an empty cell. A blank value is a cell that holds only spaces. An empty question or an empty answer teaches the model nothing, or something wrong. For example, a row with a question and no SQL teaches the model to answer with nothing.

- **[Validation 2] Duplicates.** The same example can appear more than once. The model then sees it many times, memorizes it, and does not learn the general skill. For example, if one question appears 500 times, the model learns that single answer by heart.

- **[Validation 3] Overlap between the train data and the test data.** The test data is used to test the model after the training. If a test example is also in the train data, the model has already seen it, so it only repeats what it saw. The test then says nothing about what the model learned. Three tests look for it, from the loosest to the strictest:
  - the same question, written exactly the same way;
  - the same question after lowercasing and removing extra spaces;
  - the same tables with the same answer.

Each validation has its own script. They are independent, so each one can be run on its own. Every script loads only the file or files that it needs.

#### Validation 1: Missing and blank values

This checks that the three columns that the model is trained on have data in every row. A missing value is an empty cell. A blank value is a cell that holds only spaces.

```bash
python3 - <<'EOF'
import os                           # os: Python's built-in tool for talking to the operating system. Here it reads the DATA_DIR variable.
import pandas as pd                 # pandas: a library for tables of data. "as pd" is the usual short name, so the code can write pd.read_parquet.

# ---- Load the training file ----
d = os.environ["DATA_DIR"]          # DATA_DIR is the shell variable that points to the download folder - that was created in a previioud step.
train = pd.read_parquet(f"{d}/synthetic_text_to_sql_train.snappy.parquet")  # Load the train data, which is a Parquet file, into a DataFrame table using pandas

cols = ["sql_prompt", "sql_context", "sql"]   # Save the names of the three columns that the model is trained on in a variable of type list

print("Validation 1: Missing and blank values:")
print("---------------------------------------")

# ---- Missing values ----
print("Check 1: Missing values (train):")
print(train[cols].isna().sum())     # isna() marks the empty cells, and sum() counts them for each column.

# ---- Add a separator
print("---------------------")

# ---- Blank values ----
print("Check 2: Blank values (train):")
print((train[cols].apply(lambda s: s.str.strip() == "")).sum())   # Count the cells that hold only spaces, for each of the three columns
EOF
```

Expected for Validation 1: two blocks, "Missing values" and "Blank values". Each shows `0` for `sql_prompt`, `sql_context` and `sql`. A number above 0 would mean that some rows have no data or blank data in that column.

![image5](/04-Fine-Tune/Images/image5.png)

#### Validation 2: Duplicates

This counts the examples that appear more than once in the training data.

```bash
python3 - <<'EOF'
import os               
import pandas as pd     

# ---- Load the training file ----
d = os.environ["DATA_DIR"]
train = pd.read_parquet(f"{d}/synthetic_text_to_sql_train.snappy.parquet")

cols = ["sql_prompt", "sql_context", "sql"]

print("Validation 2: Duplicates Data:")
print("------------------------------")

# ---- Duplicates ----
print("Check 1: Duplicated examples (train):")
print("Duplicate data count:   ", train.duplicated(subset=cols).sum())    # Count the examples that are repeated, comparing only the three columns
EOF
```

Expected: the count of duplicated examples in the train data, which is `0`. A number above 0 would mean that the same example appears more than once.

![image6](/04-Fine-Tune/Images/image6.png)

#### Validation 3: Overlap between the train data and the test data

This looks for test examples that also appear in the training data. It needs both files. It runs three tests, from the loosest to the strictest.

```bash
python3 - <<'EOF'
import os               
import pandas as pd    

# ---- Load the two data files ----
d = os.environ["DATA_DIR"]
train = pd.read_parquet(f"{d}/synthetic_text_to_sql_train.snappy.parquet")
test = pd.read_parquet(f"{d}/synthetic_text_to_sql_test.snappy.parquet")    # Load the test data, which is a Parquet file, into a DataFrame table using pandas

print("Validation 3: Overlap between train and test:")
print("---------------------------------------------")

# A helper that makes two questions comparable: lowercase, any run of spaces or line breaks becomes one space, and the ends are trimmed.
norm = lambda s: s.str.lower().str.replace(r"\s+", " ", regex=True).str.strip()

# --------------------------------------------------------------------
# set() turns a column into a group where each value appears only once.
# "&" compares two groups and keeps only the values that are in both.
# len() counts how many values are in the group, which gives us the number of matches.
# zip() joins the values of two columns row by row into pairs, so the tables and the answer are compared together
# So each line below counts the distinct values that appear in both files.
# --------------------------------------------------------------------

# Test 1: the same question, written exactly the same way.
print("Same question, exact:", len(set(train["sql_prompt"]) & set(test["sql_prompt"])))

# Test 2: the same question after the helper made the writing uniform.
print("Same question, normalized:", len(set(norm(train["sql_prompt"])) & set(norm(test["sql_prompt"]))))

# Test 3: the same pair of tables and answer. zip() joins the two columns row by row into pairs.
print("Same tables and same answer:", len(set(zip(train["sql_context"], train["sql"])) & set(zip(test["sql_context"], test["sql"]))))
EOF
```

Expected: three lines with the number of matches between the train data and the test data.

![image7](/04-Fine-Tune/Images/image7.png)

The overlap between the train file and the test file:

| Test | Result |
|---|---|
| Same question, written exactly the same way | 0 |
| Same question after lowercasing and removing extra spaces | 3 |
| Same tables with the same answer | 16 |

#### Findings and conclusion

**Findings**

- **Missing and blank values:** none in the three columns.
- **Duplicates:** none in the training data.
- **Overlap:** 3 questions and 16 examples in the test data also appear in the training data.

**Conclusion**

The training data has no missing values and no duplicates, so nothing is cleaned in it. The overlap is handled in phase 3: the matching rows are removed from the test data, and the training data is not changed.

---

### Phase 2: Data checking for the Axolotl settings

Some settings in the Axolotl file depend on how the dataset looks: which column is the question, how many rows there are, and how long the examples are. A wrong setting has the same result as bad data: a useless training that we only find out about at the end. So each check in this phase answers one question, and each answer sets a value in the Axolotl file.

The checks run on the laptop, in the Python virtual environment that we prepared above, and they only read the files.

- **[Check 1] The structure of the data.** Each row in the dataset is one example, and each column holds one kind of information. The Axolotl file must say which column is the question and which is the answer, and a wrong guess means the model learns the wrong thing. Column names can mislead, so one real example is read in full. *It sets: the `datasets` block, `roles_to_train`, `train_on_inputs` and `val_set_size`.*
- **[Check 2] The length of the texts, in characters.** The model reads the data in pieces of a fixed size, set with `sequence_len`. If it is too short, Axolotl drops by default the examples that do not fit. If it is too large, space is wasted. This check gives a first estimate. *It sets: a first value for `sequence_len`.*

A third check, on the tokens and the chat template, needs the converted training file. That file is built in Phase 3, so the check runs at the end of Phase 3, in step 3d. *It sets: the final `sequence_len`, `sample_packing`, `chat_template`, and `special_tokens` if needed.*

#### Check 1: The structure

This script loads both files and prints the number of rows, the name and type of each column, and the first training row in full.

```bash
python3 - <<'EOF'
import os               # os: Python's built-in tool for talking to the operating system. Here it reads the DATA_DIR variable.
import pandas as pd     # pandas: a library for tables of data. "as pd" is the usual short name, so the code can write pd.read_parquet.

d = os.environ["DATA_DIR"]                                                      # DATA_DIR is the shell variable that points to the download folder.
train = pd.read_parquet(f"{d}/synthetic_text_to_sql_train.snappy.parquet")      # Load the train data, which is a Parquet file, into a table using pandas
test = pd.read_parquet(f"{d}/synthetic_text_to_sql_test.snappy.parquet")        # Load the test data, which is a Parquet file, into a table using pandas

# ---- Size of each file ----
print("Size of each file:")
print("train rows:", len(train), "| test rows:", len(test))
print("-----------------")
print()

# ---- Column names and types ----
print("Column names and types:")
print(train.dtypes)                     # "object" is how pandas labels text columns. "int32" is a whole number.
print("-----------------")
print()

# ---- One full example ----
row = train.iloc[0]                     # iloc[0] is the first row of the training data.
print("Printing one full example:")
# Print every column of that row, one under the other, so the content of each field is visible.
for col in train.columns:
    print(f"--- {col}")
    print(row[col])
EOF
```

Expected: three parts, each followed by a separator line. `Size of each file:` shows `train rows: 100000 | test rows: 5851`. `Column names and types:` shows eleven columns: `id` is `int32` and the other ten are `object`. `Printing one full example:` shows the first training row, the forestry one, about the total volume of timber sold by each salesperson, with every column printed under its name.

![image8](/04-Fine-Tune/Images/image8.png)

| Column | Content | Used for training |
|---|---|---|
| `sql_prompt` | The question, in English | Yes. Part of the user message. |
| `sql_context` | The `CREATE TABLE` and `INSERT` statements of the example | Yes. Part of the user message. |
| `sql` | The correct SQL query | Yes. The assistant message. |
| `domain`, `domain_description`, `sql_complexity`, `sql_complexity_description`, `sql_task_type`, `sql_task_type_description`, `sql_explanation`, `id` | Descriptions, labels and the identifier | No. |

The dataset has no `messages` column. It has separate columns for the question, the tables and the answer, so the script in step 3b of Phase 3 (the conversion of the training data) builds the `messages` field from them.

The `sql_context` column holds two kinds of statements: `CREATE TABLE`, which defines a table, and `INSERT`, which adds sample rows to it. The sample rows make the text longer than the table definitions alone.

#### Check 2: The length of the texts

This script measures how long the question, the tables and the answer are, in characters, and the total for each example. The "99%" point means that 99 of every 100 examples are this long or shorter.

```bash
python3 - <<'EOF'
import os               # os: reads the DATA_DIR variable.
import pandas as pd     # pandas: tables of data.

print("Loading Data...")
d = os.environ["DATA_DIR"]
train = pd.read_parquet(f"{d}/synthetic_text_to_sql_train.snappy.parquet")   # Load the train data, which is a Parquet file, into a table using pandas
print("----Data Loaded.")
print("----------------")

cols = ["sql_prompt", "sql_context", "sql"]   # The names of the 3 columns that the model is trained on, saved in a list

print("Measuring Text Length...")
lens = pd.DataFrame({c: train[c].str.len() for c in cols})          # Build a table with the length of each text, one column per field
lens["total"] = lens.sum(axis=1)                                    # Add the total length of the three fields for each example
print("----Length Measured.")
print("----------------")

# ---- The longest example: the value that sets sequence_len ----
print("Longest Info...")
longest = lens["total"].idxmax()                                                # The row number of the example with the highest total
print("Longest example, in characters:", lens["total"].max())                   # The highest total
print("It is row number:", longest)                                             # Which row it is
print("Its sql_prompt, in characters:", lens.loc[longest, "sql_prompt"])        # The sql_prompt length
print("Its sql_context, in characters:", lens.loc[longest, "sql_context"])      # The sql_context length
print("Its sql, in characters:", lens.loc[longest, "sql"])                      # The sql length
print("----------------")

# ---- The shortest example: for information only ----
print("Shortest Info...")
shortest = lens["total"].idxmin()                                                # The row number of the example with the lowest total
print("Shortest example, in characters:", lens["total"].min())                   # The lowest total
print("It is row number:", shortest)                                             # Which row it is
print("Its sql_prompt, in characters:", lens.loc[shortest, "sql_prompt"])        # The sql_prompt length
print("Its sql_context, in characters:", lens.loc[shortest, "sql_context"])      # The sql_context length
print("Its sql, in characters:", lens.loc[shortest, "sql"])                      # The sql length
print("----------------")

# ---- Percentiles: 99 of every 100 examples are this long or shorter ----
print("Percentiles of the total length, in characters:")
print(lens["total"].quantile([0.5, 0.9, 0.99]).round(0).to_string())
EOF
```

![image9](/04-Fine-Tune/Images/image9.png)

Expected: the longest and the shortest example, each with its row number and the length of its three parts, then the percentiles of the total length.

| | Row | Question | Tables | Answer | Total |
|---|---|---|---|---|---|
| Longest example | 72,160 | 96 | 2,046 | 153 | 2,295 |
| Shortest example | 1,994 | 29 | 22 | 22 | 73 |

| Percentile of the total length | Characters |
|---|---|
| 50% (the middle) | 456 |
| 90% | 730 |
| 99% | 1,052 |

The texts are short: half of the examples have 456 characters or fewer, and the longest has 2,295. Only the longest example sets a value in the Axolotl file, because `sequence_len` must be at least as large as the longest example. The row numbers are positions in the file, counted from 0. Lengths in characters are only a first estimate, because the model counts tokens. Step 3d of Phase 3 measures the real length in tokens.

#### What Phase 2 tells us for the Axolotl file

| Question | Answer | Setting it decides |
|---|---|---|
| Which columns hold the question, the tables and the answer? | `sql_prompt`, `sql_context` and `sql`. There is no `messages` column, so step 3b builds it. | The `datasets` block: `type`, `field_messages`, `roles_to_train` and `train_on_inputs` |
| How many training rows are there? | 100,000 | `val_set_size`, and the scale of `num_epochs` or `max_steps` |
| How long is an example? | In characters: 50% have 456 or fewer, 99% have 1,052 or fewer, and the longest has 2,295. The length in tokens is checked in step 3d. | A first estimate for `sequence_len`, and `sample_packing` and `pad_to_sequence_len` |
| Do the chat template and the end-of-answer marker match what Axolotl expects? | Checked in step 3d. | `chat_template`, and `special_tokens` if needed |

One more check is left: the tokens and the chat template. It needs the training file in its final format, which does not exist yet. So it runs at the end of Phase 3, as step 3d, after the data preparation is done.

---

### Phase 3: Data preparation

In this phase we get the data ready for the fine tuning. It has four parts:

- **Handle the issues found in the validation.** The validation found 3 questions and 16 examples (same tables and same answer) in the test data that also appear in the training data. The model sees the training data during the training, so it can answer these test questions from memory. We remove them from the test data, so the final test is fair.
- **Convert the training data.** Axolotl needs to know how to turn a row of the dataset into the text that the model reads. The dataset type sets this, and Axolotl supports several types. We will use `chat_template`, which expects each example as a short conversation. Our dataset has separate columns (the question, the tables and the answer), so we convert it into conversations. The reason for this choice is explained in 3b.
- **Convert the test data.** After the training, we send the test questions to the original model and to the tuned model, and we compare their answers. The tuned model learned from conversations in one exact format, so the test questions must be sent in that same format. If they are not, the test measures a different thing from what the model learned. We apply the same conversion to the cleaned test data from 3a.
- **Check the converted training data.** This is the check that Phase 2 left for later. It measures the real length of the examples in tokens, and confirms that the format and the end-of-answer marker are the ones that the training expects.

Each part has its own script. They run in this order (3a, 3b, 3c, 3d), on the laptop, in the same environment as the checks. The scripts write their files into a new folder called `ready`, inside the dataset folder. The files that the training and the comparison need are uploaded to the cluster in a later step.

#### 3a. Handle the issues found in the validation

The validation found 3 questions and 16 examples in the test data that also appear in the training data. These rows are removed from the test data. The training data is not changed. Questions that mean the same thing with different words are not caught.

The script finds the matching test rows, removes them, and saves the rest as `test_clean.parquet`. The script in 3c reads this file.

```bash
python3 - <<'EOF'
import os
import pandas as pd

print("Loading Data...")
d = os.environ["DATA_DIR"]
train = pd.read_parquet(f"{d}/synthetic_text_to_sql_train.snappy.parquet")   # Load the train data, which is a Parquet file, into a table using pandas
test = pd.read_parquet(f"{d}/synthetic_text_to_sql_test.snappy.parquet")     # Load the test data, which is a Parquet file, into a table using pandas

out = f"{d}/ready"
os.makedirs(out, exist_ok=True)   # Create the output folder for the new files. exist_ok=True means that no error is raised if it already exists.

# A helper that makes two texts comparable: small letters, one space between words, no spaces at the ends
norm = lambda s: s.str.lower().str.replace(r"\s+", " ", regex=True).str.strip()

train_questions = norm(train["sql_prompt"])                                       # The train questions, cleaned
test_questions = norm(test["sql_prompt"])                                         # The test questions, cleaned
train_context_sql = norm(train["sql_context"]) + "\x1f" + norm(train["sql"])      # The train tables and answers, cleaned, each joined into one text
test_context_sql = norm(test["sql_context"]) + "\x1f" + norm(test["sql"])         # The test tables and answers, cleaned, each joined into one text

print("----Data Loaded.")
print("----------------")

# ---- Clean test data and remove overlap

print("Cleaning Data...")

duplicate_questions = test_questions.isin(train_questions)         # Mark each test row True if its question is also in the train questions
duplicate_context_sql = test_context_sql.isin(train_context_sql)   # Mark each test row True if its tables and answer are also in the train

overlap = duplicate_questions | duplicate_context_sql              # A test row is removed if it matches in either way
test_cleaned = test.loc[~overlap]                                  # Keep only the test rows that do not match
test_cleaned.to_parquet(f"{out}/test_clean.parquet", index=False)  # Save the cleaned test data. 3c reads this file.

print("----Data Cleaned.")
print("----------------")

print("Test rows:", len(test))
print("Same question:", duplicate_questions.sum(), "| Same tables and answer:", duplicate_context_sql.sum())
print("Removed (either way):", overlap.sum(), "| Kept:", len(test_cleaned))
EOF
```

![image10](/04-Fine-Tune/Images/image10.png)

Expected: the number of test rows (5,851), the number of rows that match the training data in each way (3 by question, 16 by tables and answer), the rows removed (19) and the rows kept (5,832). The two matches do not overlap, so the removed rows are the sum of the two counts.

Check the file is created under ready directory - `ls -lh ready/`

![image11](/04-Fine-Tune/Images/image11.png)

#### 3b. Convert the train data

The model does not read a table. For every example, it reads one piece of text. The **dataset type** is the recipe that tells Axolotl how to build that piece of text from one row of the dataset.

We use the type `chat_template`. It builds the text as a conversation, in the format of the model.

`Qwen2.5-7B-Instruct` was trained on conversations. `chat_template` builds each example with the template that comes with the model, so the model learns only the new skill (writing SQL) and not a new format on top of it.

This is what one example looks like as a conversation. Axolotl adds the special markers of the model around each message:

```
system:     You are an SQL expert. Given the tables of a database and a question, write the SQL query that answers the question.
user:       Tables: CREATE TABLE salesperson ...  Question: What is the total volume of timber sold by each salesperson?
assistant:  SELECT salesperson_id, name, SUM(volume) ...
```

There are two more reasons for this choice:

- **The format is the same everywhere.** The same template builds the prompt in the training, in the serving and in the final comparison, so the original model and the tuned model get identical inputs.
- **The training counts only the answer.** The setting `roles_to_train: ["assistant"]` makes the model learn from the SQL answer and not from the question.

The price of `chat_template` is the shape of the data. It expects each example as a list of messages. Each message has a role: `system` gives the instruction, `user` is the person who asks, and `assistant` is the model that answers. For us, the user message holds the tables and the question, and the assistant message holds the SQL answer. This is how one example is stored in the file that Axolotl reads:

```json
{"messages": [
  {"role": "system", "content": "<the fixed instruction>"},
  {"role": "user", "content": "<the tables and the question>"},
  {"role": "assistant", "content": "<the SQL answer>"}
]}
```

Two settings in the Axolotl file refer to this shape. `type: chat_template` tells Axolotl that every example is a conversation, and `field_messages: messages` tells it where the list of messages is. Our dataset has separate columns for the question, the tables and the answer, so without the conversion the training does not start, or it learns from the wrong text.

The script converts every row of the training data and writes `train.jsonl`, one example on each line.

```bash
python3 - <<'EOF'
import os               # os: reads the DATA_DIR variable and creates folders.
import json             # json: writes each example as one line of JSON text.
import pandas as pd     # pandas: tables of data.

# The fixed instruction. It must be the same text in 3b and 3c.
SYSTEM = "You are an SQL expert. Given the tables of a database and a question, write the SQL query that answers the question."

print("Loading Data...")
d = os.environ["DATA_DIR"]
train = pd.read_parquet(f"{d}/synthetic_text_to_sql_train.snappy.parquet")   # Load the train data, which is a Parquet file, into a table using pandas

out = f"{d}/ready"
os.makedirs(out, exist_ok=True)   # Create the output folder for the new files. exist_ok=True means that no error is raised if it already exists.

print("----Data Loaded.")
print("----------------")

# ---- Convert a row into a conversation ----
def to_messages(tables, question, answer):
    # The user message: the tables, then the question
    user = f"Tables:\n{tables}\n\nQuestion:\n{question}"
    # The conversation: the instruction, the user message and the answer
    return [
        {"role": "system", "content": SYSTEM},
        {"role": "user", "content": user},
        {"role": "assistant", "content": answer},
    ]

print("Converting Data...")

# ---- Write the training file: one example per line, all rows of the train data ----
with open(f"{out}/train.jsonl", "w") as f:
    for tables, question, answer in zip(train["sql_context"], train["sql_prompt"], train["sql"]):
        f.write(json.dumps({"messages": to_messages(tables, question, answer)}, ensure_ascii=False) + "\n")

print("----Data Converted.")
print("----------------")

print("Rows written to train.jsonl:", len(train))

# ---- Show the first example, as it is written in the file ----
print("\nFirst training example:")
with open(f"{out}/train.jsonl") as f:
    print(json.dumps(json.loads(f.readline()), indent=2, ensure_ascii=False))
EOF
```

![image12](/04-Fine-Tune/Images/image12.png)

Expected: the four banner lines, then `Rows written to train.jsonl: 100000`, then the first training example, printed as a conversation with three messages: `system`, `user` and `assistant`. The user message starts with `Tables:` and then holds the tables and the question. The first example is the forestry one, about the total volume of timber sold by each salesperson. The file `train.jsonl` is saved in the `ready` folder.

Check the file is created under ready directory - `ls -lh ready/`

![image13](/04-Fine-Tune/Images/image13.png)

#### 3c. Convert the test data

After the training, we send the test questions to the original model and to the tuned model, and we compare their answers. The tuned model learned from conversations in one exact format, so the test questions must be sent in that same format. If they are not, the test measures a different thing from what the model learned.

This script applies the same conversion as 3b to the cleaned test data that 3a saved. The correct SQL stays in the assistant message as the reference answer, and the comparison removes it before it asks the model. The script also keeps the test id and the complexity level for each question, so the results can be shown for each level. Most test examples are simple SQL, so one score for everything would mostly describe the easy cases.


```bash
python3 - <<'EOF'
import os               # os: reads the DATA_DIR variable.
import json             # json: writes each example as one line of JSON text.
import pandas as pd     # pandas: tables of data.

# The fixed instruction. It must be the same text as in 3b.
SYSTEM = "You are an SQL expert. Given the tables of a database and a question, write the SQL query that answers the question."

print("Loading Data...")
d = os.environ["DATA_DIR"]
out = f"{d}/ready"
test_clean = pd.read_parquet(f"{out}/test_clean.parquet")   # Load the cleaned test data, which is a Parquet file, into a table using pandas

print("----Data Loaded.")
print("----------------")

# ---- Convert a row into a conversation (the same function as in 3b) ----
def to_messages(tables, question, answer):
    # The user message: the tables, then the question
    user = f"Tables:\n{tables}\n\nQuestion:\n{question}"
    # The conversation: the instruction, the user message and the answer
    return [
        {"role": "system", "content": SYSTEM},
        {"role": "user", "content": user},
        {"role": "assistant", "content": answer},
    ]

print("Converting Data...")

# ---- Write the test file: one example per line, with the test id and the complexity level ----
with open(f"{out}/test.jsonl", "w") as f:
    for _, r in test_clean.iterrows():
        record = {
            "test_id": int(r["id"]),
            "sql_complexity": r["sql_complexity"],
            "messages": to_messages(r["sql_context"], r["sql_prompt"], r["sql"]),
        }
        f.write(json.dumps(record, ensure_ascii=False) + "\n")

print("----Data Converted.")
print("----------------")

print("Rows written to test.jsonl:", len(test_clean))

# ---- How many test rows there are for each complexity level ----
print("\nRows for each complexity level:")
print(test_clean["sql_complexity"].value_counts().to_string())
EOF
```

![image14](/04-Fine-Tune/Images/image14.png)

Expected: the four banner lines, then `Rows written to test.jsonl: 5832`, then the number of test rows for each of the 8 complexity levels. The numbers add up to 5,832.

| Complexity level | Test rows |
|---|---|
| basic SQL | 2,863 |
| aggregation | 1,292 |
| single join | 885 |
| subqueries | 386 |
| window functions | 196 |
| multiple_joins | 139 |
| set operations | 51 |
| CTEs | 20 |

The levels with few rows, such as CTEs, give a rough result, because one question moves their score by several points.

Check the file is created under ready directory - `ls -lh ready/`

![image15](/04-Fine-Tune/Images/image15.png)

#### 3d. Check the converted training data for the Axolotl settings

This is the last step of Phase 3. Axolotl is the framework that runs the fine-tuning. It reads `train.jsonl`, the file that step 3b built, and several settings in the Axolotl file depend on what is inside it. So before the file is uploaded, we check four things.

Two of the problems that these checks look for give no error. Axolotl drops an example that is too long without a warning, and a wrong end marker leaves the model without a signal to stop writing. Nothing would warn us until the end of the project, after the GPU time was spent. They cost nothing to check now.

The model does not read our messages as they are. It reads one piece of text, where every message is wrapped in special markers. This is one finished example, as the model receives it. The tables are shortened with `...`:

```
<|im_start|>system
You are an SQL expert. Given the tables of a database and a question, write the SQL query that answers the question.<|im_end|>
<|im_start|>user
Tables:
CREATE TABLE salesperson (...); INSERT INTO salesperson (...) VALUES (...); CREATE TABLE timber_sales (...); INSERT INTO timber_sales (...) VALUES (...);

Question:
What is the total volume of timber sold by each salesperson, sorted by salesperson?<|im_end|>
<|im_start|>assistant
SELECT salesperson_id, name, SUM(volume) as total_volume FROM timber_sales JOIN salesperson ON ... ORDER BY total_volume DESC;<|im_end|>
```

`<|im_start|>` opens a message and names who is speaking. `<|im_end|>` closes it.

These are the four checks:

1. **The token length.** In Check 2 of Phase 2, we measured the longest example in characters, to get a first idea for `sequence_len`. But the model reads tokens, which are small pieces of text, and `sequence_len` counts tokens. So this step counts the tokens of the finished text of every example. We plan to use 2,048, so the longest example must not go above it. If an example is longer than `sequence_len`, Axolotl drops it from the training, and it does not warn us. The model would then learn from less data than we think, and we would not know which examples were lost.
2. **The chat template.** We use `chat_template` as the dataset type because `Qwen2.5-7B-Instruct` was trained on conversations in its own format. The template is the set of rules that turns our plain messages into the finished text above. It comes with the tokenizer of the model, and we do not write it. When the Axolotl file says `chat_template: tokenizer_default`, Axolotl takes the template from the tokenizer. So we check that the tokenizer has one. If it did not, there would be nothing to build the text with, and the script would stop with an error.
3. **The start and the end.** The markers keep the messages apart, and they tell the model who is speaking and where each message stops. Every example must begin with `<|im_start|>system`, followed by our instruction. This shows that our system message is the first thing that the model reads, in the format that it already knows. Every example must also end with the `eos_token`, which is `<|im_end|>` for this model. It is the signal for "stop writing", and the model learns to give it right after the SQL. The Axolotl docs warn that the `eos_token` of the tokenizer must match the end marker of the template. If they differ, the model may write a correct query and then keep going with invented text, and we would only see it at the end, when the model is tested. The template adds a line break after the last marker, and the check ignores it.
4. **One finished example.** Finally, the script prints the first example in full, as the model receives it, and we read it ourselves. The markers, the system message, the tables, the question and the answer must all be there, in the right order. The other checks give a yes or no. This one shows what the model really reads.

The script loads the tokenizer of `Qwen2.5-7B-Instruct` and reads `train.jsonl`. The first run downloads the tokenizer files, which are a few MB.

```bash
python3 - <<'EOF'
import os                                   # os: reads the DATA_DIR variable.
import pandas as pd                         # pandas: reads the file into a table.
from transformers import AutoTokenizer      # AutoTokenizer: loads the tokenizer of a model from Hugging Face

SEQUENCE_LEN = 2048                         # The value of sequence_len in the Axolotl file

# ---- Load The Model Tokenizer ----
print("Loading Tokenizer...")
tok = AutoTokenizer.from_pretrained("Qwen/Qwen2.5-7B-Instruct")   # Load the tokenizer of the model, which includes its chat template
print("----Tokenizer Loaded.")
print("----------------")

# ---- Load Converted Data ----
print("Loading Data...")
d = os.environ["DATA_DIR"]                                                      # DATA_DIR is the shell variable that points to the dataset folder.
messages = pd.read_json(f"{d}/ready/train.jsonl", lines=True)["messages"]       # Load train.jsonl into a table, and keep the messages column: one item for each 
print("----Data Loaded.")
print("----------------")

# ---- Check 1: the token length ----
print("Check 1: The token length")
print("Counting Tokens...")
longest = 0                              # The highest number of tokens found so far
too_long = 0                             # The number of examples that are longer than SEQUENCE_LEN
for m in messages:
    text = tok.apply_chat_template(m, tokenize=False)                       # Combine the system, user and assistant messages of this example into one text
    n = len(tok(text, add_special_tokens=False)["input_ids"])               # Cut the text into tokens and count them
    if n > longest:
        longest = n                                                         # This example is the longest so far, so save its token count
    if n > SEQUENCE_LEN:
        too_long = too_long + 1                                             # This example is above the limit, so count it as too long
print("----Tokens Counted.")
print("Longest example, in tokens:", longest)
print("Examples longer than", SEQUENCE_LEN, "tokens:", too_long)
print("----------------")

# ---- Check 2: the chat template ----
print("Check 2: The chat template")
print("Has a chat template:", tok.chat_template is not None)
print("----------------")

# The finished text of the first example, as the model receives it
first = tok.apply_chat_template(messages.iloc[0], tokenize=False)

# ---- Check 3: the start and the end ----
print("Check 3: The start and the end of the text")
print("Starts with <|im_start|>system:", first.startswith("<|im_start|>system"))
print("eos_token:", tok.eos_token)                                                  # The marker that means the message ends here
print("Ends with the eos_token:", first.rstrip().endswith(tok.eos_token))          # rstrip() removes the line break at the end
print("----------------")

# ---- Check 4: one finished example ----
print("Check 4: One finished example, as the model receives it")
print(first)
print("----------------")
EOF
```

![image16](/04-Fine-Tune/Images/image16.png)

Expected: the messages for loading the tokenizer and the data, then four checks, each followed by a separator line. Two warnings can appear at the top (one about the SSL library of the laptop's Python, and one that says PyTorch is not installed). They are not errors, because only the tokenizer is used.

| Check | Result |
|---|---|
| 1. The token length | The longest example has 715 tokens, and 0 examples are longer than 2,048 |
| 2. The chat template | `True` |
| 3. The start and the end | The start check says `True`. The `eos_token` is `<\|im_end\|>`, and the end check says `True` |
| 4. One finished example | The first example in full, as in the box above, with the markers, the system message, the tables, the question and the answer |

**What 3d decides**

| Check | Answer | Setting it decides |
|---|---|---|
| The token length | The longest example has 715 tokens, and none is longer than 2,048, so nothing is dropped. Even the longest example uses about a third of a piece, so at least two examples fit in each piece. | `sequence_len: 2048`, and `sample_packing: true` |
| The chat template | The tokenizer has one. | `chat_template: tokenizer_default` |
| The start and the end | The text starts with the system message and ends with the `eos_token`. | `special_tokens` is not needed |
| One finished example | The text has the markers, the system message and the three parts in the right order. | No setting. It confirms the format. |

#### The files

The scripts of Phase 3 create these files in the `ready` folder, inside the dataset folder on the laptop:

| File | Made by | Rows | Goes to the cluster | Used for |
|---|---|---|---|---|
| `test_clean.parquet` | 3a | 5,832 | No. It is only the input of 3c. | The test data without the rows that also appear in the training data |
| `train.jsonl` | 3b | 100,000 | Yes | The training data, in the conversation format. The `datasets` block of the Axolotl file points to it. |
| `test.jsonl` | 3c | 5,832 | Yes | The test data, in the same conversation format, for the final comparison |

The check in 3d reads `train.jsonl`, and it does not create a file. The two files that go to the cluster are uploaded in the next section.

The instruction text at the top of the 3b and 3c scripts (`SYSTEM`) must be exactly the same in both, and so must the layout of the user message. The original model and the tuned model receive the test questions in this same format. If one script is changed and the other is not, the test measures something different from what the model learned, and no error appears.

---

## Uploading the data

The data is uploaded from the laptop to the shared `/mnt/data` filesystem of the cluster. These files go to the cluster:

| File | Made by | Goes to | Used for |
|---|---|---|---|
| The two Parquet files and the dataset card | The download | `/mnt/data/data/raw/` | The dataset as published. They are kept as a record, and they are the source of the two files below. |
| `train.jsonl` | 2b | `/mnt/data/data/` | The training. The `datasets` block of the Axolotl file points to it. |
| `test.jsonl` | 2c | `/mnt/data/data/` | The final comparison of the original model and the tuned model. |

`test_clean.parquet` (the input of 2c) and the four `.txt` files stay on the laptop.

The commands use three variables. They last only as long as the terminal window, so they are set again in a new window:

```bash
export DATA_DIR=~/Downloads/dataset_synthetic_text_to_sql
export KEY=~/.ssh/taher-soperator-demoday
export LOGIN_IP=$(kubectl -n soperator get svc soperator-login-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

### Step 1: Check the files and record their checksums

This lists the files that will be uploaded and calculates a checksum for each data file. A checksum is a short fingerprint of a file's content. After the upload, the fingerprint is calculated again on the cluster. If it matches, the copy is identical to the original.

```bash
cd "$DATA_DIR"
ls -lh
shasum -a 256 *.parquet
shasum -a 256 ready/train.jsonl ready/test.jsonl
```

![image17](/04-Fine-Tune/Images/image17.png)

Expected: the dataset folder holds the `ready` folder, the four `.txt` files, the dataset card (8.2k) and the two Parquet files (the test file at 1.9M and the train file at 32M). Four checksums are printed. The two for the Parquet files are the same as in the download section, and the two for the JSONL files are the ones that the upload must reproduce on the cluster. The checksums are saved for Step 4.

### Step 2: Prepare the folders on the cluster

This connects to the login node, checks that `/mnt/data` is the large shared filesystem, and creates the folder layout for the whole phase. The check comes first, because a folder created on the wrong disk would fill the small boot disk of the login node.

> [!NOTE]
> The next steps run partly on the Slurm login pod and partly on the laptop. To keep the two apart, open a new terminal window for the upload and use it only for the laptop commands. Do not use the window that is already logged in to the login pod.
>
> In the new window, set the three variables and move to the dataset folder:
>
> ```bash
> export DATA_DIR=~/Downloads/dataset_synthetic_text_to_sql
> export KEY=~/.ssh/taher-soperator-demoday
> export LOGIN_IP=$(kubectl -n soperator get svc soperator-login-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
> cd "$DATA_DIR"
> ```

```bash
ssh -i "$KEY" root@"$LOGIN_IP"
```

```bash
df -h /mnt/data
ls -ld /mnt/data
mkdir -p /mnt/data/data/raw /mnt/data/hf-cache /mnt/data/outputs /mnt/data/configs /mnt/data/logs /mnt/data/prepared
ls -la /mnt/data
```

| Folder | Used for |
|---|---|
| `/mnt/data/data/raw` | The downloaded Parquet files and the dataset card, as published |
| `/mnt/data/data` | `train.jsonl` and `test.jsonl`, the files that the training and the comparison read |
| `/mnt/data/hf-cache` | The Hugging Face cache, shared by both nodes |
| `/mnt/data/outputs` | Checkpoints and the final adapter |
| `/mnt/data/configs` | The Axolotl YAML file |
| `/mnt/data/logs` | Training and measurement logs |
| `/mnt/data/prepared` | The tokenized dataset that Axolotl saves |

Expected: `df` shows the `jail-submount-data` filesystem, 1.0T in size, mounted on `/mnt/data`, with nothing used. After `mkdir`, the last command lists the six folders.

![image18](/04-Fine-Tune/Images/image18.png)

### Step 3: Upload the files

This copies the Parquet files and the dataset card to the raw folder, and the two JSONL files to the data folder. The four `.txt` files are not needed and stay on the laptop.

> [!NOTE]
> The command below runs in the terminal of the laptop, and not on the Slurm login pod. Go back to the laptop terminal before you run it.

```bash
scp -i "$KEY" *.parquet README.md root@"$LOGIN_IP":/mnt/data/data/raw/
scp -i "$KEY" ready/train.jsonl ready/test.jsonl root@"$LOGIN_IP":/mnt/data/data/
```

Expected: one progress line for each file. The first connection may ask to accept the host key. Type `yes`. `train.jsonl` is the largest file, so it takes the longest.

![image19](/04-Fine-Tune/Images/image19.png)

### Step 4: Verify the upload

This computes the checksums again on the cluster and lists the files.

> [!NOTE]
> The commands below run on the Slurm login pod, and not on the laptop. Go to the terminal that is logged in to the login pod before you run them.

```bash
cd /mnt/data/data/raw
ls -lh
sha256sum *.parquet

cd ..
ls -lh
sha256sum train.jsonl test.jsonl
```

Expected: the same file sizes as on the laptop, and the same four checksums as in Step 1. The sizes can look slightly different, because the laptop and the cluster round file sizes in different units. The checksum is the reliable check. The command on the cluster is `sha256sum`, which gives the same kind of fingerprint as `shasum -a 256` on the laptop. The command `shasum` without `-a 256` gives a shorter, different fingerprint, so its output cannot be compared with the laptop's.

![image20](/04-Fine-Tune/Images/image20.png)

### Step 5: Check that the worker nodes see the same files

The upload went to the login pod. The training job runs on the two worker nodes, so both workers must see the same files in `/mnt/data`. This step runs a small Slurm job on both workers. Each worker prints its own name and the checksums of the data files.

Log in to the login pod and run:

```bash
srun -l -N2 --ntasks-per-node=1 bash -c 'hostname && sha256sum /mnt/data/data/raw/*.parquet /mnt/data/data/train.jsonl /mnt/data/data/test.jsonl'
```

The flag `-N2` starts the job on two nodes. `--ntasks-per-node=1` runs one task on each node. `-l` adds the task number to every output line, so the output of the two workers can be told apart.

Expected: two blocks of output, one for `worker-0` and one for `worker-1`, marked `0:` and `1:`. Each block shows the same four checksums as in Step 1. The lines of the two workers can appear in a mixed order, because the workers run at the same time. Slurm also prints `cpu-bind` lines. They are informational messages and can be ignored.

![image21](/04-Fine-Tune/Images/image21.png)

Reading works. Writing must work too, because both workers write to `/mnt/data` during training (the cache and the checkpoints). This test writes a file on `worker-0`, reads it on `worker-1`, and then removes it:

```bash
srun -N1 -w worker-0 bash -c 'echo "written by worker-0" > /mnt/data/logs/node_test.txt'
srun -N1 -w worker-1 cat /mnt/data/logs/node_test.txt
rm /mnt/data/logs/node_test.txt
```

Expected: the second command prints `written by worker-0`. A file written on one worker is visible on the other, so both workers share the same filesystem for reading and writing.

![image22](/04-Fine-Tune/Images/image22.png)

---

## Checking flash attention

We run the fine-tuning inside a container on the Slurm worker nodes. The image is `axolotlai/axolotl:main-20261013-py3.12-cu130-2.13.0`.

Flash attention makes the attention step faster and uses less memory. We want it, but we do not know yet if this image supports it. This check tests two things: whether `flash_attn` is installed in the image, and whether the PyTorch flash kernel works on the H100.

> **Note:** Run both commands below on the login pod. The first one creates the script on the shared disk. The second one runs it on a worker, inside the container.

> [!NOTE]
> The commands below run on the Slurm login pod, and not on the laptop. Go to the terminal that is logged in to the login pod before you run them.

Create the check script:

```bash
cat > /mnt/data/logs/flash_check.py <<'EOF'
import torch
from torch.nn.attention import sdpa_kernel, SDPBackend

# flash_attn package: installed or not
try:
    import flash_attn
    print("flash_attn package:", flash_attn.__version__)
except ImportError:
    print("flash_attn package: not installed")

# Tensors in the shape of Qwen2.5-7B: 28 heads, head size 128, 2048 tokens, bf16
q = torch.randn(1, 28, 2048, 128, device="cuda", dtype=torch.bfloat16)
k = torch.randn_like(q)
v = torch.randn_like(q)

# Force PyTorch to use only its flash kernel. It raises an error if the kernel cannot run.
try:
    with sdpa_kernel(SDPBackend.FLASH_ATTENTION):
        out = torch.nn.functional.scaled_dot_product_attention(q, k, v, is_causal=True)
    torch.cuda.synchronize()
    print("PyTorch flash kernel in sdpa: works, output", tuple(out.shape))
except Exception as e:
    print("PyTorch flash kernel in sdpa: FAILED -", e)
EOF
ls -l /mnt/data/logs/flash_check.py
```

![image23](/04-Fine-Tune/Images/image23.png)

Run the check script as a slurm job:

```bash
srun --nodes=1 --gres=gpu:1 --cpus-per-task=16 \
  --container-image=axolotlai/axolotl:main-20261013-py3.12-cu130-2.13.0 \
  --container-mounts=/mnt/data:/mnt/data \
  python3 /mnt/data/logs/flash_check.py
```

![image24](/04-Fine-Tune/Images/image24.png)

| Line | Result |
|---|---|
| `flash_attn` package | `not installed` |
| PyTorch flash kernel in `sdpa` | `works, output (1, 28, 2048, 128)` |

We also ran the same script on `axolotlai/axolotl:main-latest` and `axolotlai/axolotl-cloud:main-latest`. The result was the same, so no other image is better.

**Findings**

- The image does not have the `flash_attn` package. So `flash_attention_2` is not an option.
- The flash kernel of PyTorch works on the H100, in bf16, with the shape of Qwen2.5-7B (28 heads, head size 128, 2048 tokens, causal).

**What this changes**

| Item | Change |
|---|---|
| `attn_implementation` | Stays `sdpa`. It uses the flash kernel of PyTorch, so we get flash attention without the package. |
| The image | No change. We keep the pinned image. |
| The YAML file | No change. |
| The open point on flash attention | Closed, except for one thing: the smoke test must show that Axolotl uses this kernel with `sample_packing`. |

This check proves that the kernel works in PyTorch. It does not prove that Axolotl uses it during training. The smoke test shows that, through the speed and the GPU memory.

---

## The Axolotl configuration

Axolotl runs the whole fine-tune from one YAML file. The file says which model to train, which data to use, how to train it and where to save the result. Everything that we found in the checks and in the data preparation is now written into it.

The file below holds only the settings that this job needs, with a short comment next to each one. A setting that is left out keeps its Axolotl default. Every key was checked against the current [Axolotl config reference](https://docs.axolotl.ai/docs/config-reference.html).

> [!NOTE]
> For the full explanation of each setting, what it does, what a bad value costs and why the value was chosen, see [axolotl_yaml-config.yaml](/04-Fine-Tune/axolotl_yaml-config.yaml).

> [!NOTE]
> The steps below run on the Slurm login pod. If you are not logged in to it, log in first with `ssh -i "$KEY" root@"$LOGIN_IP"`. If you are already logged in, go to that terminal.

Create the file `lora-sql-qwen7b.yaml` in `/mnt/data/configs/`. Open it with `vi`, then paste the content of the YAML file below. In `vi`, press `i` before you paste, then press `Esc` and type `:wq` to save.

```bash
cd /mnt/data/configs
vi lora-sql-qwen7b.yaml
cat lora-sql-qwen7b.yaml
```

![image25](/04-Fine-Tune/Images/image25.png)

```yaml
# ---- Model and method ----
base_model: Qwen/Qwen2.5-7B-Instruct        # The model to fine-tune. It is not gated, so no Hugging Face token is needed
adapter: lora                               # Train a small LoRA adapter on top of the frozen model
lora_r: 16                                  # Rank of the adapter. A higher rank learns more and uses more memory
lora_alpha: 32                              # Strength of the adapter. 2 x the rank is a common rule
lora_dropout: 0.05                          # Drops a small share of adapter values while training, to reduce overfitting
lora_target_linear: true                    # Put the adapter on all linear layers, not only on attention
bf16: true                                  # Train in bfloat16. The H100 supports it
attn_implementation: sdpa                   # PyTorch attention. Flash attention is not installed in the container.

# ---- Data ----
datasets:
  - path: /mnt/data/data/train.jsonl        # The training file from step 3b, on the shared filesystem
    type: chat_template                     # Each row is a conversation, built with the chat template
    field_messages: messages                # The field that holds the list of messages
    roles_to_train: ["assistant"]           # Learn from the SQL answer only
chat_template: tokenizer_default            # Use the template that comes with the Qwen tokenizer
train_on_inputs: false                      # Do not learn from the prompt (the tables and the question)
val_set_size: 0.01                          # Hold back 1% of the training data (1,000 rows) to draw the validation curve
dataset_prepared_path: /mnt/data/prepared   # Where the tokenized data is saved, so both nodes and later runs reuse it

# ---- Sequence and packing ----
sequence_len: 2048                          # Size of one piece, in tokens. The longest example has 715, so nothing is dropped
sample_packing: true                        # Put several short examples in one piece, instead of empty padding
pad_to_sequence_len: true                   # Pad every piece to the same size, so memory use stays steady

# ---- Batch and length of the run ----
micro_batch_size: 4                         # Pieces per GPU in one pass. [TO TUNE] in the smoke test
gradient_accumulation_steps: 4              # Passes added up before one update. [TO TUNE]
num_epochs: 1                               # Passes over the training data. [TO CONFIRM] max_steps can replace it
learning_rate: 0.0002                       # Size of each update. A common value for LoRA
warmup_steps: 10                            # The learning rate rises from zero over the first 10 steps
dataloader_num_workers: 4                   # Processes that prepare the batches. [TO TUNE] Each node has 16 vCPUs

# ---- Logging and saving ----
logging_steps: 5                                    # Log the loss every 5 steps
evals_per_epoch: 4                                  # Run the validation 4 times per epoch
saves_per_epoch: 4                                  # Save a checkpoint 4 times per epoch
save_total_limit: 2                                 # Keep only the 2 latest checkpoints
output_dir: /mnt/data/outputs/qwen25-7b-sql-lora    # Where the checkpoints and the final adapter are written
seed: 42                                            # Fixes the random choices, so two runs can be compared
```

---

## Running the smoke test

The smoke test runs the real config on one worker for 20 steps. It checks that the file loads, the data is read, `sdpa` works with `sample_packing`, and the GPU trains. It also measures the GPU memory and the GPU utilization, which settle `micro_batch_size` and `dataloader_num_workers`.

The test is one command. Inside the job, `nvidia-smi` samples the GPU every 2 seconds in the background and writes the values to a CSV file. When the training ends, the sampler stops.

- `--max-steps 20` stops the run after 20 steps.
- `--output-dir` keeps the test files away from the real output folder.
- `HF_HOME` stores the model download on the shared disk, so worker-1 reuses it later.
- `nvidia-smi ... -l 2 > ... &` samples the GPU every 2 seconds, in the background.
- `SMI=$!` saves the sampler's process ID, and `kill $SMI` stops the sampler after the training.

> **Note:** Run all the commands below on the login pod. The first run is slow, because it downloads the model (about 15 GB) and tokenizes the data. Later runs reuse both.

**Step 1. Start the test**

```bash
srun --nodes=1 --gres=gpu:1 --cpus-per-task=16 --time=00:40:00 \
  --container-image=axolotlai/axolotl:main-20261013-py3.12-cu130-2.13.0 \
  --container-mounts=/mnt/data:/mnt/data \
  bash -c 'export HF_HOME=/mnt/data/hf-cache
nvidia-smi --query-gpu=timestamp,utilization.gpu,memory.used --format=csv -l 2 > /mnt/data/logs/gpu_smoke.csv &
SMI=$!
axolotl train /mnt/data/configs/lora-sql-qwen7b.yaml --max-steps 20 --output-dir /mnt/data/outputs/smoke2
kill $SMI' \
  2>&1 | tee /mnt/data/logs/smoke2.log
```

Expected: the run ends without an error, after about 4 minutes. The last log line is `Model successfully saved to /mnt/data/outputs/smoke2`.

![image26](/04-Fine-Tune/Images/image26.png)

**Step 2. Read the key lines of the log**

```bash
grep -E "sdpa_varlen|'loss'|'eval_loss'|train_runtime|successfully saved" /mnt/data/logs/smoke2.log
```

![image27](/04-Fine-Tune/Images/image27.png)

Expected: one line that says `sdpa_varlen: patched 'sdpa' to use cu_seqlens varlen_attn for packed rows`. Then a `loss` line every 5 steps, an `eval_loss` line before training and after every 5 steps, one `train_runtime` line, and the line that the model is saved.

**Step 3. Summarize the GPU samples**

```bash
awk -F', ' 'NR>1 && $2+0>0 {n++; s+=$2+0; if ($2+0<50) low++} END {if (n) printf "Samples with the GPU busy: %d\nAverage utilization: %.0f%%\nSamples below 50%%: %d\n", n, s/n, low}' /mnt/data/logs/gpu_smoke.csv
```

![image28](/04-Fine-Tune/Images/image28.png)

Expected: three lines with the number of busy samples, the average utilization and the number of samples below 50%. The samples at exactly 0% are not counted, so the model loading at the start does not lower the average.

**Step 4. Look at the last 40 samples**

```bash
tail -n 40 /mnt/data/logs/gpu_smoke.csv
```

Expected: one line every 2 seconds with the time, the GPU utilization and the memory used. During training the utilization is 96–100%. It drops to 0–2% for a few seconds at each validation and checkpoint.

![image29](/04-Fine-Tune/Images/image29.png)

**Result**

| Check | Result |
|---|---|
| The run ends without an error | Yes. 20 steps in 128 seconds. The final model is saved to `/mnt/data/outputs/smoke2`. |
| `sdpa` is accepted | Yes. The log says Axolotl patched `sdpa` to use `varlen_attn` for packed rows (head size 128, limit 256). Packing works with `sdpa`. |
| The loss goes down | Yes. Training loss 1.06 at step 5, 0.22 at step 15. Validation loss 1.21 before training, 0.22 at step 20. |
| GPU memory used | 67.4 GiB allocated and 70.2 GiB reserved in the log. `nvidia-smi` shows 73,151 MiB, about 90% of the card. |
| Average GPU utilization | 81% over 50 busy samples. The samples at exactly 0% are not counted. |
| Samples below 50% | 7 |
| Seconds per step | About 3.1. The progress bar shows 3.9, but that number includes the validation and checkpoint time. |
| Checkpoints are written | Yes. `checkpoint-15` and `checkpoint-20` are kept (`save_total_limit: 2`). The final adapter is in the output folder: `adapter_model.safetensors` and `adapter_config.json`. |

The utilization is 96–100% while the model trains. The dips are at the validation and the checkpoint. With `--max-steps 20` they happen every 5 steps, so they lower the average. In the real run they happen about every 141 steps.

The data was prepared once and saved to `/mnt/data/prepared`. The log shows 100,000 examples, a longest example of 715 tokens, and a packing efficiency of about 98.7%. The next runs reuse it.

**What the result decides**

| Question | Answer |
|---|---|
| `micro_batch_size` | Stays at 4. The memory is about 90% of the card without gradient checkpointing. A larger value would very likely run out of memory. |
| `dataloader_num_workers` | Stays at 4. The GPU is at 96–100% while it trains, so it does not wait for data. |
| Does Axolotl use `varlen_attn` with `sample_packing`? | Yes, from the log. |

---

## Testing on two nodes

The smoke test used one GPU. This test proves that both GPUs train as one job, over the Ethernet link between the nodes. It also gives the real step time for two GPUs, which decides `gradient_accumulation_steps` and `num_epochs`.

With two GPUs, each optimizer step uses 4 × 4 × 2 = 32 pieces of 2,048 tokens. The training data is split between the two GPUs, and they exchange the LoRA gradients once per step.

Axolotl runs the training with `torchrun`. `torchrun` starts one process on each node. The nodes find each other through a rendezvous point, which is `worker-0` here.

- `--nodes=2 --ntasks-per-node=1 --nodelist=worker-0,worker-1` runs one task on each node, with `worker-0` first.
- `--launcher torchrun --` tells Axolotl to start the training with `torchrun`. Everything after `--` goes to `torchrun`.
- `--nnodes 2 --nproc_per_node 1` means 2 nodes with 1 GPU each.
- `--rdzv_backend c10d --rdzv_endpoint worker-0:29400` is the meeting point. Both nodes connect to `worker-0` on port 29400.
- `--rdzv_id smoke2node` is a name shared by both nodes for this job.
- `NCCL_DEBUG=INFO` makes NCCL print which network it uses. We want to see that it uses the Ethernet interface.
- Each node writes its own GPU file, `gpu_2node_<node name>.csv`.

> **Note:** Run all the commands below on the login pod.

```bash
srun --nodes=2 --ntasks-per-node=1 --nodelist=worker-0,worker-1 \
  --gres=gpu:1 --cpus-per-task=16 --time=00:40:00 \
  --container-image=axolotlai/axolotl:main-20261013-py3.12-cu130-2.13.0 \
  --container-mounts=/mnt/data:/mnt/data \
  bash -c 'export HF_HOME=/mnt/data/hf-cache
export NCCL_DEBUG=INFO
nvidia-smi --query-gpu=timestamp,utilization.gpu,memory.used --format=csv -l 2 > /mnt/data/logs/gpu_2node_$SLURMD_NODENAME.csv &
SMI=$!
axolotl train /mnt/data/configs/lora-sql-qwen7b.yaml --max-steps 20 --output-dir /mnt/data/outputs/smoke-2node --launcher torchrun -- --nnodes 2 --nproc_per_node 1 --rdzv_id smoke2node --rdzv_backend c10d --rdzv_endpoint worker-0:29400
kill $SMI' \
  2>&1 | tee /mnt/data/logs/2node.log
```

![image30](/04-Fine-Tune/Images/image30.png)

Expected: both nodes start and train as one job. The log shows `world_size` 2. The loss prints every 5 steps and goes down. The run ends with `Model successfully saved to /mnt/data/outputs/smoke-2node`.

**Result**

| Check | Result |
|---|---|
| The run ends without an error | Yes. 20 steps in 108.5 seconds. The final model is saved to `/mnt/data/outputs/smoke-2node`. |
| Both nodes take part | Yes. `world_size` is 2, and both nodes load the model and the prepared data. |
| Each step uses twice the data | Yes. `epoch` is 0.01768 at step 5, against 0.008842 on one node. |
| The loss goes down | Yes. Validation loss 1.214 before training, 0.22 at step 20. This is the same as on one node (0.2208). |
| GPU memory on each node | 67.6 GiB allocated and 70.4 GiB reserved, the same on both. |
| Seconds per step | 3.19 on two nodes, against 3.17 on one. The difference is under 1%. **(checked outside)** |
| GPU utilization while training | Median 96% on both nodes. The average is 71% on worker-0 and 70% on worker-1. **(checked outside)** |
| Steps in one epoch | About 283 on two GPUs, against about 565 on one. **(checked outside)** |

**Checked outside.** These rows are not visible in the screenshot.
- *Seconds per step.* This is the time between a checkpoint save and the next validation in `/mnt/data/logs/2node.log`, divided by 5 steps. I used the same method for the one-node log. The progress bar shows 3.5 s per step on two nodes and 3.9 on one, but it includes validation, which is twice as fast on two GPUs.
- *GPU utilization.* It comes from the files `/mnt/data/logs/gpu_2node_worker-0.csv` and `gpu_2node_worker-1.csv`, for the samples where the memory is above 60,000 MiB (the model is training). The average is lower than the median because the GPU is idle for about 4 seconds before each validation, which happens every 5 steps in this test. In the real run it happens about every 71 steps.
- *Steps in one epoch.* Step 20 is 0.07073 of an epoch, so one epoch is 20 ÷ 0.07073 ≈ 283 steps.

**What the result decides**

| Question | Answer | Setting it decides |
|---|---|---|
| Does the network slow the step? | No. The step time is the same as on one node. | `gradient_accumulation_steps` stays at 4 |
| Does the second GPU double the work in each step? | Yes. Each step uses 32 pieces of 2,048 tokens, against 16 on one node. | `micro_batch_size` stays at 4 |
| Is the GPU busy while it trains? | Yes. The median is 96% on both nodes. The 80% target is confirmed in the real run, where validation is less frequent. | `dataloader_num_workers` stays at 4 |
| How long does one epoch take? | About 283 steps × 3.2 s, plus validation and saves, so about 16 minutes. | `num_epochs`: 1 epoch is about 16 minutes, 1.5 epochs about 24 minutes, 2 epochs about 31 minutes |

---

## Updating the configuration

The tests settled the values that were marked `[TO TUNE]`. None of them changes. We only update the comments, so that the file says what was tested.

| Setting | Value | Status |
|---|---|---|
| `attn_implementation` | `sdpa` | Confirmed. The flash kernel of PyTorch works on the H100, and Axolotl uses it for packed rows. |
| `micro_batch_size` | 4 | Confirmed. It uses about 90% of the 80 GB card. There is no room to go higher. |
| `gradient_accumulation_steps` | 4 | Confirmed. The network does not slow the step on two nodes. |
| `dataloader_num_workers` | 4 | Confirmed. The GPU is busy while it trains (median 96%). |
| `num_epochs` | 1 | Not decided. One epoch takes about 16 minutes on two GPUs. |

The only value that can still change is `num_epochs`. If we change it, the training just runs longer or shorter, and no new test is needed.

---

## Running the fine-tuning

This is the real run. It uses the final config in `/mnt/data/configs/lora-sql-qwen7b.yaml` with no override. The tests settled every value, so nothing changes.

| Setting | Value |
|---|---|
| Model | `Qwen/Qwen2.5-7B-Instruct`, LoRA (rank 16) in bf16 |
| Nodes and GPUs | 2 nodes, 1 H100 each |
| Batch | 4 pieces per GPU × 4 accumulation steps × 2 GPUs = 32 pieces of 2,048 tokens per step |
| Length | 1 epoch, 282 steps |
| Output | `/mnt/data/outputs/qwen25-7b-sql-lora` |

The command starts one training job on both nodes. The training data is split between the two GPUs, and they exchange the LoRA gradients once per step. Axolotl runs the training with `torchrun`, which starts one process on each node. The nodes find each other through a meeting point, which is `worker-0` here.

- `--nodes=2 --ntasks-per-node=1 --nodelist=worker-0,worker-1` runs one task on each node, with `worker-0` first.
- `--gres=gpu:1 --cpus-per-task=16` gives each task one GPU and all 16 CPUs of the node.
- `--time=01:00:00` is a safety limit. Slurm stops the job after 1 hour. The run itself takes about 14 minutes.
- `--container-image` and `--container-mounts` run the job in the pinned Axolotl image, with the shared disk `/mnt/data` mounted at the same path.
- `HF_HOME=/mnt/data/hf-cache` reuses the model that is already downloaded on the shared disk.
- `nvidia-smi ... -l 2 > ... &` samples the GPU every 2 seconds, in the background. Each node writes its own file, `gpu_run_<node name>.csv`. `SMI=$!` saves the process ID of the sampler, and `kill $SMI` stops it when the training ends.
- `axolotl train /mnt/data/configs/lora-sql-qwen7b.yaml` starts the training with the final config. There is no `--max-steps`, so the run goes to the end of the epoch. There is no `--output-dir`, so the adapter goes to the folder in the YAML.
- `--launcher torchrun --` tells Axolotl to start the training with `torchrun`. Everything after `--` goes to `torchrun`.
- `--nnodes 2 --nproc_per_node 1` means 2 nodes with 1 GPU each.
- `--rdzv_backend c10d --rdzv_endpoint worker-0:29400` is the meeting point. Both nodes connect to `worker-0` on port 29400.
- `--rdzv_id finetune` is a name shared by both nodes for this job.
- `2>&1 | tee /mnt/data/logs/train.log` shows the output on the screen and saves it to the file `train.log`.

> **Note:** Run the commands below on the login pod. Keep the terminal open until the run ends. It takes about 14 minutes, including the model loading.

**Step 1. Check that the cluster is free**

```bash
squeue
```

Expected: the list is empty. If an old job is still running, wait for it to end, because it holds the GPU.

**Step 2. Start the training**

```bash
srun --nodes=2 --ntasks-per-node=1 --nodelist=worker-0,worker-1 \
  --gres=gpu:1 --cpus-per-task=16 --time=01:00:00 \
  --container-image=axolotlai/axolotl:main-20261013-py3.12-cu130-2.13.0 \
  --container-mounts=/mnt/data:/mnt/data \
  bash -c 'export HF_HOME=/mnt/data/hf-cache
nvidia-smi --query-gpu=timestamp,utilization.gpu,memory.used --format=csv -l 2 > /mnt/data/logs/gpu_run_$SLURMD_NODENAME.csv &
SMI=$!
axolotl train /mnt/data/configs/lora-sql-qwen7b.yaml --launcher torchrun -- --nnodes 2 --nproc_per_node 1 --rdzv_id finetune --rdzv_backend c10d --rdzv_endpoint worker-0:29400
kill $SMI' \
  2>&1 | tee /mnt/data/logs/train.log
```

![image31](/04-Fine-Tune/Images/image31.png)

Expected: the log shows `world_size` 2 and `Maximum number of steps set at 282`. Both nodes load the prepared data and the model, and the log shows `trainable params: 40,370,176` (0.5273%). A first validation runs before step 1 (validation loss 1.214). Then the loss prints every 5 steps and goes down, from 1.064 to about 0.18. A validation and a checkpoint come at steps 71, 142, 213 and 282, and the validation loss goes down at each one (0.1915, 0.1834, 0.1788, 0.1773). The run ends with `Model successfully saved to /mnt/data/outputs/qwen25-7b-sql-lora`.

**Step 3. Check the output folder**

```bash
ls -lh /mnt/data/outputs/qwen25-7b-sql-lora
```

![image32](/04-Fine-Tune/Images/image32.png)

Expected: the files `adapter_model.safetensors` and `adapter_config.json`, the tokenizer files, and two `checkpoint-` folders (`checkpoint-213` and `checkpoint-282`, because `save_total_limit` is 2).

**Step 4. Read the key lines of the log**

```bash
grep -E "'loss'|'eval_loss'|train_runtime|successfully saved" /mnt/data/logs/train.log | tail -n 20
```

![image33](/04-Fine-Tune/Images/image33.png)

Expected: the last loss lines (about 0.18), the last validation loss (`eval_loss` 0.1773), the `train_runtime` line (782.8 seconds, `train_loss` 0.2092), and the line `Model successfully saved to /mnt/data/outputs/qwen25-7b-sql-lora`.

**Result**

| Check | Result |
|---|---|
| The run ends without an error | Yes. 282 steps (99.7% of an epoch). The model is saved to `/mnt/data/outputs/qwen25-7b-sql-lora`. |
| Final training loss | 0.1845 at the last logged step. The average over the run is 0.2092. |
| Final validation loss | 0.1773 (perplexity 1.194). It was 1.214 before the training. |
| Total training time (`train_runtime`) | 782.8 seconds (13 min 3 s). The whole job took about 14 minutes. |
| GPU utilization on worker-0 | [TO FILL] |
| GPU utilization on worker-1 | [TO FILL] |
| Adapter files are in the output folder | [TO FILL] |

---

## Testing the tuned model

The training is done, and the loss went down. This test shows that the adapter really changes what the model does. We send the same 20 questions to the original model and to the tuned model, and we compare the answers with the correct SQL.

The questions come from `/mnt/data/data/test.jsonl`, the test file that the model never saw during the training. The script uses rows 0 to 19.

The script does this:
- It loads `Qwen/Qwen2.5-7B-Instruct` with no adapter, which is the original model, and answers the 20 questions.
- It adds the adapter from `/mnt/data/outputs/qwen25-7b-sql-lora` to the same model and answers the same 20 questions.
- For each question, it prints the correct SQL, the answer of the original model, the answer of the tuned model, and whether the two answers are the same.
- At the end, it prints a summary: how many answers are the same, how many match the correct SQL, and how many have a markdown code block around the SQL.
- It uses greedy decoding (`do_sample=False`), so there is no randomness, and the same question always gives the same answer.

The match with the correct SQL is strict. The script lowercases both texts, removes `;` and extra spaces, and then compares them. Two different queries can give the same result, so a miss does not always mean the SQL is wrong.

> **Note:** Run the commands below on the login pod. Check with `squeue` that the cluster is free before you start.

**Step 1. Create the script**

```bash
cat > /mnt/data/logs/compare.py <<'EOF'
import sys, json, torch
from transformers import AutoTokenizer, AutoModelForCausalLM
from peft import PeftModel

BASE = "Qwen/Qwen2.5-7B-Instruct"
ADAPTER = "/mnt/data/outputs/qwen25-7b-sql-lora"

rows = [json.loads(line) for line in open("/mnt/data/data/test.jsonl")]
idx = [int(a) for a in sys.argv[1:]] or list(range(20))

tok = AutoTokenizer.from_pretrained(BASE)
model = AutoModelForCausalLM.from_pretrained(BASE, torch_dtype=torch.bfloat16, device_map={"": 0})
model.eval()

def ask(m, messages):
    prompt = messages[:-1]                     # system + user. The last message is the correct answer, so we drop it.
    text = tok.apply_chat_template(prompt, tokenize=False, add_generation_prompt=True)
    ids = tok(text, return_tensors="pt").to("cuda")
    with torch.no_grad():
        out = m.generate(**ids, max_new_tokens=300, do_sample=False)
    return tok.decode(out[0][ids["input_ids"].shape[1]:], skip_special_tokens=True).strip()

def norm(s):
    return " ".join(s.lower().replace(";", " ").split())

# 1. The original model, no adapter
base_answers = {i: ask(model, rows[i]["messages"]) for i in idx}

# 2. The same model with the adapter
model = PeftModel.from_pretrained(model, ADAPTER)
model.eval()
tuned_answers = {i: ask(model, rows[i]["messages"]) for i in idx}

for i in idx:
    msgs = rows[i]["messages"]
    user = next(m for m in msgs if m["role"] == "user")["content"]
    print("=" * 70)
    print("ROW", i)
    print("QUESTION:", user.split("Question:")[-1].strip())
    print("\nCORRECT SQL:\n" + msgs[-1]["content"])
    print("\nORIGINAL MODEL:\n" + base_answers[i])
    print("\nTUNED MODEL:\n" + tuned_answers[i])
    print("\nSAME ANSWER:", base_answers[i] == tuned_answers[i])

ref = {i: rows[i]["messages"][-1]["content"] for i in idx}
n = len(idx)
print("=" * 70)
print("SUMMARY FOR", n, "QUESTIONS")
print("Same answer from both models:        ", sum(base_answers[i] == tuned_answers[i] for i in idx), "of", n)
print("Original model matches correct SQL:  ", sum(norm(base_answers[i]) == norm(ref[i]) for i in idx), "of", n)
print("Tuned model matches correct SQL:     ", sum(norm(tuned_answers[i]) == norm(ref[i]) for i in idx), "of", n)
print("Original answers with a code block:  ", sum("```" in base_answers[i] for i in idx), "of", n)
print("Tuned answers with a code block:     ", sum("```" in tuned_answers[i] for i in idx), "of", n)
EOF
ls -l /mnt/data/logs/compare.py
```

Expected: `ls` shows the file `compare.py`.

**Step 2. Run the test on one worker**

```bash
srun --nodes=1 --gres=gpu:1 --cpus-per-task=16 --time=00:30:00 \
  --container-image=axolotlai/axolotl:main-20261013-py3.12-cu130-2.13.0 \
  --container-mounts=/mnt/data:/mnt/data \
  bash -c 'export HF_HOME=/mnt/data/hf-cache && python3 /mnt/data/logs/compare.py' \
  2>&1 | tee /mnt/data/logs/compare.log
```

Expected: after the model loads (about 1 minute), 20 blocks, one for each row, and then the summary. The warnings about `torch_dtype` and `KernelPreference` are harmless.

**Result**

Result: the run finished with no errors. For every question, the original model gave an explanation with the SQL inside a markdown code block. The tuned model gave one line of SQL and nothing else.

| Check | Result |
|---|---|
| Same answer from both models | 0 of 20 |
| Original model matches the correct SQL | 0 of 20 |
| Tuned model matches the correct SQL | 8 of 20 |
| Original answers with a code block | 20 of 20 |
| Tuned answers with a code block | 0 of 20 |

**What the result shows**

| Question | Answer |
|---|---|
| Does the adapter change the output? | Yes. All 20 answers are different. |
| Does the tuned model follow the format of the training data (SQL only)? | Yes. 20 of 20 answers are SQL only, with no code block and no explanation. |
| Is the tuned answer closer to the correct SQL? | Yes, in most rows. 8 are exactly the same as the correct SQL. Others are very close, for example rows 6, 9, 14 and 18. |
| Is the tuned model always right? | No. In rows 10, 13 and 17 the query is different from the correct one. |

For the full output of `compare.log`, see [fine_tuning_compare.txt](fine_tuning_compare.txt).

---





```bash
cat > /mnt/data/logs/compare-3ep.py <<'EOF'
import sys, json, torch
from transformers import AutoTokenizer, AutoModelForCausalLM
from peft import PeftModel

BASE = "Qwen/Qwen2.5-7B-Instruct"
ADAPTER = "/mnt/data/outputs/qwen25-7b-sql-lora-3ep"

rows = [json.loads(line) for line in open("/mnt/data/data/test.jsonl")]
idx = [int(a) for a in sys.argv[1:]] or list(range(20))

tok = AutoTokenizer.from_pretrained(BASE)
model = AutoModelForCausalLM.from_pretrained(BASE, torch_dtype=torch.bfloat16, device_map={"": 0})
model.eval()

def ask(m, messages):
    prompt = messages[:-1]                     # system + user. The last message is the correct answer, so we drop it.
    text = tok.apply_chat_template(prompt, tokenize=False, add_generation_prompt=True)
    ids = tok(text, return_tensors="pt").to("cuda")
    with torch.no_grad():
        out = m.generate(**ids, max_new_tokens=300, do_sample=False)
    return tok.decode(out[0][ids["input_ids"].shape[1]:], skip_special_tokens=True).strip()

def norm(s):
    return " ".join(s.lower().replace(";", " ").split())

# 1. The original model, no adapter
base_answers = {i: ask(model, rows[i]["messages"]) for i in idx}

# 2. The same model with the adapter
model = PeftModel.from_pretrained(model, ADAPTER)
model.eval()
tuned_answers = {i: ask(model, rows[i]["messages"]) for i in idx}

for i in idx:
    msgs = rows[i]["messages"]
    user = next(m for m in msgs if m["role"] == "user")["content"]
    print("=" * 70)
    print("ROW", i)
    print("QUESTION:", user.split("Question:")[-1].strip())
    print("\nCORRECT SQL:\n" + msgs[-1]["content"])
    print("\nORIGINAL MODEL:\n" + base_answers[i])
    print("\nTUNED MODEL:\n" + tuned_answers[i])
    print("\nSAME ANSWER:", base_answers[i] == tuned_answers[i])

ref = {i: rows[i]["messages"][-1]["content"] for i in idx}
n = len(idx)
print("=" * 70)
print("SUMMARY FOR", n, "QUESTIONS")
print("Same answer from both models:        ", sum(base_answers[i] == tuned_answers[i] for i in idx), "of", n)
print("Original model matches correct SQL:  ", sum(norm(base_answers[i]) == norm(ref[i]) for i in idx), "of", n)
print("Tuned model matches correct SQL:     ", sum(norm(tuned_answers[i]) == norm(ref[i]) for i in idx), "of", n)
print("Original answers with a code block:  ", sum("```" in base_answers[i] for i in idx), "of", n)
print("Tuned answers with a code block:     ", sum("```" in tuned_answers[i] for i in idx), "of", n)
EOF
ls -l /mnt/data/logs/compare-3ep.py
```