# 06 - Benchmarking

> Benchmarking the original and the fine-tuned `Qwen2.5-7B-Instruct` on speed and performance with `GuideLLM`, against the two `vLLM` servers.

---

# Description

This section holds everything needed to benchmark the two models that we serve in [05-Serve](/05-Serve/README.md): the original model, and the model that we fine-tuned in [04-Fine-Tuning](/04-Fine-Tune/README.md). The cluster is built in [03-Provision](/03-Provision/README.md).

It covers task 3 of the Nebius Demo Day: run the original model, before your training or fine-tuning, and compare its results with those of your trained model.

We send the same SQL questions to both models with `GuideLLM`, and we measure how fast each model answers and how much work each model can do. `GuideLLM` is an open-source benchmark tool for LLM servers. It calls the OpenAI-compatible API of a server, sends a controlled load, and records the time of every request.

This section measures and compare the original model and the tuned model on speed and performance only, and it does not measure the accuracy of the answers. We use the 11 measurements below:
- **TTFT (time to first token).** The total time from sending the question until the first token arrives. p50 means half of the requests are faster than this. p95 means 95 out of 100 are faster, so it shows the slow end.
- **ITL (inter-token latency).** The time between one token and the next while the model writes. A lower value means the text streams faster.
- **Output length.** The average number of tokens in one answer. It tells us whether one model writes longer answers than the other.
- **End-to-end latency.** The total time from sending the question until the last token arrives. We report p50 and p95.
- **Output tokens per second.** How many tokens the server writes each second when it is full. This is the main speed figure for the whole server.
- **Requests per second.** How many answers the server finishes each second when it is full.
- **Latency against load.** How the waiting time grows when more requests arrive at the same moment. It is the curve that the sweep draws.
- **Error and timeout rate.** The share of requests that fail or time out. We expect 0%.
- **KV-cache capacity.** How many tokens the GPU can hold for open conversations. vLLM prints it when it starts.
- **Start-up time.** How long vLLM needs from its first log line until the server is ready.
- **Estimated TFLOPS.** How much arithmetic the GPU does each second, estimated from the tokens per second. We compare it with the H100 peak.

The section gives the strategy and the reasons behind it, and a short explanation of the tool. Then it gives the preparation tasks, and a step-by-step guide with every command.

**The infrastructure in short**

For full details, please refer to [03-Provision](/03-Provision/README.md) and [05-Serve](/05-Serve/README.md).

- **`worker-0`:** a Slurm worker pod on a GPU node, with one H100 80 GB. It serves the original model with `vLLM`.
- **`worker-1`:** the same, with one H100 80 GB. It serves the tuned model with `vLLM`.
- **`vllm-qwen-base` and `vllm-qwen-tuned`:** two internal `ClusterIP` Services on port 8000. They give each `vLLM` server a stable name inside the cluster.
- **Slurm login:** a pod on a system node. We use it to submit and restart the `vLLM` jobs.
- **System nodes:** CPU nodes with 8 vCPU each. The `GuideLLM` client runs here, on its own pod, so it never takes CPU from `vLLM`.
- **Shared filesystem:** mounted on all nodes at `/mnt/data`. It holds the test questions, the key file and the results.
- **Open WebUI:** the chat page from 05. It stays idle during the benchmark.

---

# Strategy and why

## What we compare

The strategy is to send the same questions to both models, one model at a time, and to record the time of every answer. We compare the two models on 11 points. The points cover how long a user waits, how fast the text streams, how many answers the server can give per second, what it costs, and how the GPU is used.

The question is simple, but the answer needs some care. A server behaves differently when it is busy. With one user, the answer comes back at once. With 200 users at the same moment, each user waits longer, even though the GPU works at full speed. A real service has many users, so we do not test one load. We test a ladder of loads, from one request at a time up to the point where the server is full.

The test has three design choices, and each one is explained below: where the client runs, what the client calls, and how we compare the length of the answers.

## Where the client runs

The client is the program that sends the requests. If it is slow, the result shows the client and not the server. We have three options:

| Option | What it means | Cost |
|---|---|---|
| Run `GuideLLM` on a worker node | The client starts next to `vLLM` on the GPU node. | The client takes CPU from `vLLM`, and the result measures both of them. |
| **Run `GuideLLM` in a pod on a system node** | A small pod sends the load over the cluster network and mounts the shared `/mnt/data`. | The pod needs free CPU on a system node. These nodes are small, with 8 vCPU each. |
| Run `GuideLLM` on the Slurm login pod | Install it with `pip` in a virtual environment on the login pod. | The login pod has only 4 vCPU, and it is shared with the Slurm users. |

We use the second option. The pod is pinned to a released version of `GuideLLM`, so every rerun uses the same software.

## What the client calls

| Option | What it means | Cost |
|---|---|---|
| Call the models through `Open WebUI` | The client uses the same path as the chat page. | `Open WebUI` adds its own defaults to a request, and it adds a layer to every time we measure. |
| **Call the two `vLLM` Services directly** | The client uses `vllm-qwen-base` and `vllm-qwen-tuned` inside the cluster, with the API key. | The public path through the load balancer is not measured. |

We use the second option. We measure the two servers and nothing else.

## How we compare the length of the answers

The two models answer in a different way. The original model writes an explanation around the SQL. The tuned model writes the SQL and nothing else. A model that writes fewer tokens finishes sooner, so it looks faster. A token is a small piece of a word. The question is whether the model is faster because the answer is shorter, or because the engine is faster. One test cannot answer both questions, so we have three options:

| Option | What it means | Cost |
|---|---|---|
| Only natural answers | Each model writes its own answer. | We cannot tell if a speed difference comes from the engine or from the length of the answer. |
| Only equal answers | Both models must write exactly 128 tokens. | It is not what a user sees. |
| **Both: scenario A and scenario B** | In scenario A, each model writes its natural answer. In scenario B, both models must write exactly 128 tokens. | Two tests for each model instead of one. |

We use the third option.

- **Scenario A, natural answers.** This is the main result. It shows what a user feels: how long one answer takes, how many answers the server gives per second, and what 1,000 answers cost.
- **Scenario B, equal answers.** Both models receive the same questions, and both are forced to write exactly 128 tokens. We set `max_tokens` to 128, and we set `ignore_eos` to true, so the model keeps writing even when it would normally stop. Now both models do the same work, and any difference left comes from the engine. The text after the natural end of a short answer has no meaning, but the speed of producing a token does not depend on the text. Scenario B is an engine test only. It does not show what the tuned model does for a user.

## What we compare: the twelve points

| # | Point | What it means | Where it comes from |
|---|---|---|---|
| 1 | TTFT | Time to first token: the wait between sending the request and the first token. | Scenario A and B |
| 2 | Inter-token latency | The time between two tokens while the model writes. A lower value means that the text streams faster. | Scenario A and B |
| 3 | Output length | The average number of tokens in one answer. | Scenario A |
| 4 | End-to-end latency | The time from sending the request to the last token. It equals TTFT plus the number of tokens minus one, times the inter-token latency. The first token is already inside TTFT. | Scenario A |
| 5 | Output tokens per second at saturation | How many tokens the server produces each second when it is full. | Scenario A and B |
| 6 | Requests per second at saturation | How many answers the server finishes each second when it is full. | Scenario A |
| 7 | Latency against load | How the waiting time grows when more requests arrive at the same moment. It is the curve of the sweep. | Scenario A |
| 8 | Error and timeout rate | The share of requests that fail or time out. | All tests |
| 9 | KV-cache capacity | The number of tokens that the GPU can hold for open conversations. `vLLM` prints it when it starts. | `vLLM` log |
| 10 | Start-up time | The time that `vLLM` needs from its first log line until the server is ready. | `vLLM` log |
| 11 | Estimated TFLOPS | How many trillions of arithmetic operations the GPU does each second while the model writes. It shows how much of the GPU's calculating power the model uses. We compare it with the peak of the H100. | Estimated from point 5 |

## Key decisions

| Decision | Choice | Why |
|---|---|---|
| Benchmark tool | **GuideLLM**, release v0.8.1 | It measures every time we need, and it writes JSON and CSV files. |
| Where the client runs | A **pod on a system node**, with a pinned image | On a worker it would take CPU from `vLLM`. |
| What the client calls | The two `vLLM` **Services**, directly | No extra layer in the measurement. |
| Questions | The SQL test file, **without the correct answers**, in the training format | The model must not see the answer, and it gets the same input as in training. |
| Temperature | **0** | The same question gives the same answer. |
| Load | A **sweep**, with 30 seconds for each level | It finds saturation by itself. |
| Scenarios | **A** with natural answers, **B** with 128 forced tokens | It separates the length of the answer from the speed of the engine. |
| Order | One model at a time, the original first, then the tuned model | The other server stays idle, so the two never disturb each other. |
| Number of runs | Each test runs **once** | It is a demo, and one run shows the size of the difference. |
| `vLLM` CPU | **12 CPUs** for each job | `vLLM` needs CPU for tokenizing and scheduling. |
| `vLLM` API processes | **4** for each server | One API process can use only one CPU core. |
| Prefix cache | **Off** | The 5,832 questions fit in the cache, so a repeated question would look faster than it is. |
| Scope | Speed and performance only | The accuracy of the answers is not measured here. |

---

# The new tools

One tool in this section is new to the project: `GuideLLM`.

## GuideLLM

`GuideLLM` is a benchmark tool for LLM servers. It sends requests to any OpenAI-compatible server, such as `vLLM`, and it measures how the server behaves under load. For every request it records the time to the first token, the time between tokens, the total time, and the number of tokens. It then turns these numbers into statistics, and it writes them to the console and to files.

It has three parts that matter for us:
- **The profile** sets the load. The `sweep` profile runs many levels, from one request at a time up to the maximum.
- **The data** sets what the client sends. It can generate text on its own, or it can read a file. We use a file of SQL questions.
- **The output** sets what we get back. During the run, the console shows a live table with one row for each level. At the end it prints the final tables and saves a JSON file and a CSV file.

**How we use it.** We run `GuideLLM` v0.8.1 in a pod on a system node. We start it with one command for each test, and we point it at one `vLLM` Service at a time. We run four tests: scenario A and scenario B, for each of the two models. The JSON and CSV files go to the shared filesystem, and we copy the numbers into this README.

- GitHub: [github.com/vllm-project/guidellm](https://github.com/vllm-project/guidellm)
- Documentation: [vllm-project.github.io/guidellm](https://vllm-project.github.io/guidellm/) (the pages for the release that we use are at [vllm-project.github.io/guidellm/0.8.1](https://vllm-project.github.io/guidellm/0.8.1/))
- Container image: `ghcr.io/vllm-project/guidellm`

---

# Preparation

Before we run the tests, we do four preparation tasks:

- **Preparation 1:** suspend the `enroot-cleanup` health check, and cancel its waiting jobs.
- **Preparation 2:** give the `vLLM` servers more CPU and more API processes, turn off the prefix cache, and restart both servers.
- **Preparation 3:** build the prompt file: the test questions without the correct answers.
- **Preparation 4:** keep the system quiet.

## Preparation 1: Suspend the `enroot-cleanup` health check

The cluster runs a health check called `enroot-cleanup` as a Slurm job, twice a day, at 08:10 and 20:10 UTC. It asks for all the memory of a node. While a `vLLM` job holds a worker, the check waits in the queue. It starts on its own the moment a worker is free, for example when we restart a `vLLM` server. A running check would delay the server, and it would disturb a test. The benchmark does not need it, so we suspend it and cancel the jobs that are waiting.

> [!NOTE]
> The first block runs on the laptop. The second block runs on the Slurm login pod.
> If you are not logged in to the Slurm login pod, use the commands below to log in:
>
> ```bash
> export KEY=~/.ssh/taher-soperator-demoday
> export LOGIN_IP=$(kubectl -n soperator get svc soperator-login-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
> ssh -i $KEY root@$LOGIN_IP
> ```
>
> If your kucectl is not working - login to nebius and access the managed kubernetes cluster and then click on `how to connect`
>

**Suspend the check (laptop)**

```bash
kubectl -n soperator get activecheck enroot-cleanup
kubectl -n soperator patch activecheck enroot-cleanup --type=merge -p '{"spec":{"suspend":true}}'
kubectl -n soperator get activecheck enroot-cleanup
```

![image1](/06-Benchmarking/Images/image1.png)

Expected: the first command shows `enroot-cleanup` with `SUSPEND` set to `false`. The second prints `patched`. The third shows `SUSPEND` set to `true`. Suspending only stops new runs. It does not delete the check.

**Cancel the waiting jobs (Slurm login pod)**

```bash
squeue -t PD -o "%.8i %.14j %.9P %.6D %R"
scancel -n enroot-cleanup
squeue
```

![image2](/06-Benchmarking/Images/image2.png)

Expected: The last command shows only the two `vLLM` jobs, `vllm-ori` on `worker-0` and `vllm-tun` on `worker-1`, both in state `R`.

## Preparation 2: Give `vLLM` more CPU and more API processes, and restart the servers

The two servers from 05 work well for a chat. A benchmark pushes much harder, and three settings matter.

- **CPU.** Slurm gives every GPU 4 CPUs by default, and our `sbatch` files do not ask for more. `vLLM` needs CPU for tokenizing, scheduling and streaming the tokens back. With only 4 CPUs, the CPU can limit the result before the GPU does. We give each job 12 CPUs. A worker has 16, and the worker pod is limited to about 14, so the rest stays free for the system.
- **API processes.** The `vLLM` front door, the API server, is one process, and one process uses one CPU core only. Under high load it can become a limit before the GPU does. We run four API processes with `--api-server-count 4`.
- **Prefix cache.** `vLLM` keeps the computed questions in a cache, and it is on by default. Our test file has 5,832 questions, and all of them fit in the cache. A question that we send a second time would come from the cache and look faster than it is. We turn the cache off with `--no-enable-prefix-caching`, so every test starts from the same state.

> [!NOTE]
> All commands in this task run on the Slurm login pod.

**Check the CPU of the running servers**

```bash
scontrol show node worker-0 | grep -E 'CPUAlloc|AllocTRES'
scontrol show node worker-1 | grep -E 'CPUAlloc|AllocTRES'
```

Expected: each worker shows `CPUAlloc=4` and `AllocTRES=cpu=4,mem=176G`. The job holds 4 of the 16 CPUs, and it holds all the memory of the node. This is why the `enroot-cleanup` jobs could not start.

**Edit the two `sbatch` files**

The first command adds a CPU line to the header of each file. The second adds the CPU option to the `srun` line. The third adds the two `vLLM` options after the last line of the `vllm serve` command. Run this block once. A second run adds the lines again.

```bash
for f in /mnt/data/serve/serve-qwen-base.sbatch /mnt/data/serve/serve-qwen-tuned.sbatch; do
  sed -i 's/^#SBATCH --gres=gpu:1$/#SBATCH --gres=gpu:1\n#SBATCH --cpus-per-task=12/' $f
  sed -i 's/^srun --container-image=/srun --cpus-per-task=12 --container-image=/' $f
  sed -i 's/--generation-config vllm$/--generation-config vllm \\\n    --api-server-count 4 --no-enable-prefix-caching/' $f
done
```

Check the final result for the sbatch scripts

```bash
grep -n -E 'cpus-per-task|api-server-count|prefix-caching' /mnt/data/serve/serve-qwen-base.sbatch /mnt/data/serve/serve-qwen-tuned.sbatch
```

![image3](/06-Benchmarking/Images/image3.png)

Expected: each file shows three lines. `#SBATCH --cpus-per-task=12` is on line 6, `srun --cpus-per-task=12 ...` is on line 13, and `--api-server-count 4 --no-enable-prefix-caching` is on line 21. Each line appears once. If a line appears twice, the block ran twice.

**Restart `Qwen-Base`**

We restart one server at a time, so one model always stays up. The command cancels the old job, submits the new one, and waits until all four API processes report `Application startup complete`. It waits for up to 5 minutes. Then it checks the job and the log, and asks the server for its model list with the key.

```bash
squeue                          # Show the running jobs.
scancel -n vllm-original        # Cancel the old base job.
squeue                          # Show that only the tuned job is left.
sbatch /mnt/data/serve/serve-qwen-base.sbatch       # Submit the edited base file. Slurm prints the new job number.
squeue                          # Show the new job. The state R means that it is running. Check the Job ID
JOB="<job-id>"                  # Save the new job number with the number that sbatch printed.
# Follow the log and show one line each time an API process is ready. Press Ctrl+C after the fourth line.
tail -F /mnt/data/logs/vllm-original-$JOB.log | grep 'Application startup complete'
scontrol show job $JOB | tr ' ' '\n' | grep -E '^(JobState|NumCPUs)='   # Check that the job runs and that it has 12 CPUs.
# Check the four API processes and the KV-cache size in the log.
grep -n -E 'Started server process|Application startup complete|GPU KV cache size' /mnt/data/logs/vllm-original-$JOB.log | cut -c1-180
```

![image4](/06-Benchmarking/Images/image4.png)

Expected: the first `squeue` shows the base job on `worker-0` and the tuned job on `worker-1`. After the cancel, only the tuned job is left. `sbatch` prints `Submitted batch job` and the new number. The next `squeue` shows the new job with the state `R`, so the GPU on `worker-0` was free at once. The `tail` command prints four `Application startup complete` lines, one for each API process. The server is ready after the fourth line, so press Ctrl+C only then. The job shows `JobState=RUNNING` and `NumCPUs=12`. The log shows four `Started server process` lines and four `Application startup complete` lines, one for each API process. It also shows one `GPU KV cache size: 1,013,728 tokens` line, with a maximum concurrency of 247.49x for requests of 4,096 tokens.

The job is running, but we also check that the server answers a request with the key. The first command reads the key from the key file. The second command asks the server for its list of models and shows the first 120 characters.

```bash
KEYV=$(cat /mnt/data/secrets/vllm.key)
curl -s -H "Authorization: Bearer $KEYV" http://vllm-qwen-base:8000/v1/models | head -c 120; echo
```

![image5](/06-Benchmarking/Images/image5.png)

Expected: the server answers with a JSON list. It shows `"object":"list"`, the model name `"id":"Qwen-Base"`, and `"owned_by":"vllm"`. The `root` field starts with the model path `Qwen/Qwen2.5-`, and the rest is cut off at 120 characters. The key does not appear in the output.

**Restart `Qwen-Tuned`**

Run this block only when `Qwen-Base` is up. We restart one server at a time, so one model always stays up. The commands cancel the old job, submit the new one, and wait until all four API processes report `Application startup complete`. Then they check the job and the log.

```bash
squeue                          # Show the running jobs.
scancel -n vllm-tuned           # Cancel the old tuned job.
squeue                          # Show that only the new base job is left.
sbatch /mnt/data/serve/serve-qwen-tuned.sbatch      # Submit the edited tuned file. Slurm prints the new job number.
squeue                          # Show the new job. The state R means that it is running. Check the Job ID
JOB="<job-id>"                  # Save the new job number with the number that sbatch printed.
# Follow the log and show one line each time an API process is ready. Press Ctrl+C after the fourth line.
tail -F /mnt/data/logs/vllm-tuned-$JOB.log | grep 'Application startup complete'
scontrol show job $JOB | tr ' ' '\n' | grep -E '^(JobState|NumCPUs)='   # Check that the job runs and that it has 12 CPUs.
# Check the four API processes and the KV-cache size in the log.
grep -n -E 'Started server process|Application startup complete|GPU KV cache size' /mnt/data/logs/vllm-tuned-$JOB.log | cut -c1-180
```

![image6](/06-Benchmarking/Images/image6.png)

Expected: Similar to the base model, we expect `JobState=RUNNING` and `NumCPUs=12`. The log shows four `Started server process` lines and four `Application startup complete` lines, one for each API process. It also shows `GPU KV cache size: 1,013,728 tokens`, the same as the base model.

We check the server as we did for the base model. The first command reads the key from the key file. The second command asks the server for its list of models, with the tuned service name in the URL.

```bash
KEYV=$(cat /mnt/data/secrets/vllm.key)
curl -s -H "Authorization: Bearer $KEYV" http://vllm-qwen-tuned:8000/v1/models | head -c 120; echo
```

![image7](/06-Benchmarking/Images/image7.png)

Expected: the server answers with a JSON list. It shows `"object":"list"`, the model name `"id":"Qwen-Tuned"`, and `"owned_by":"vllm"`. The `root` field shows the start of the path of the merged model, and the rest is cut off at 120 characters. The key does not appear in the output.

## Preparation 3: Build the prompt file

`GuideLLM` reads the questions from a file, and it sends the messages in the file as they are. Our test file from 04, `test.jsonl`, has three messages in every row: the system message, the user message, and the assistant message. The assistant message is the correct SQL. If we gave this file to `GuideLLM`, the model would receive the correct answer inside its own prompt, and the test would be useless.

So we build a new file, `prompts.jsonl`. It keeps the system message and the user message, and it drops the assistant message. The system text and the layout of the user message stay exactly as in training, so both models get the same input that the model learned from. The script also puts the rows in a fixed random order, with seed 42. `GuideLLM` takes the rows from the top of the file, so the order decides which questions the tests use first. A fixed order gives both models the same questions in the same order.

The script runs on the Slurm login pod, on the `test.jsonl` file that is already on the shared disk from 04. It needs only Python 3, with no extra packages. The new file goes into `/mnt/data/benchmark`.

> [!NOTE]
> The commands in this task run on the Slurm login pod, in the same way as the commands in 05.

**Create the folders**

The client pod runs as a normal user, and not as root. It needs to write its result files into `/mnt/data/benchmark/results`, so the command also opens the permissions of the two folders.

```bash
# Create the benchmark folder and the results folder, and let the client pod write into them.
mkdir -p /mnt/data/benchmark/results && chmod 777 /mnt/data/benchmark /mnt/data/benchmark/results
```

**Build the prompt file**

The script reads the test file, removes the correct SQL answer from every row, and mixes the rows with a fixed seed. The model gets the system message and the question, and nothing else.

```bash
python3 - <<'EOF'
import json             # json: reads and writes each example as one line of JSON text.
import random           # random: mixes the order of the rows, with a fixed seed.

src = "/mnt/data/data/test.jsonl"             # the test file from 04: system, user and assistant messages
dst = "/mnt/data/benchmark/prompts.jsonl"     # the new file: system and user messages only

print("Loading Data...")
rows = [json.loads(line) for line in open(src)]       # read the test file, one example per line
print("Rows read:", len(rows))

print("----Data Loaded.")
print("----------------")

print("Editing Data...")
out = [{"test_id": r["test_id"], "messages": r["messages"][:2]} for r in rows]      # keep the system and user messages, drop the correct SQL
random.shuffle(out)                                                                 # mix the rows
print("Rows edited:", len(out))

print("----Data Edited.")
print("----------------")

print("Saving Data...")
with open(dst, "w") as f:
    for r in out:
        f.write(json.dumps(r, ensure_ascii=False) + "\n")     # write one example per line
print("Rows written:", len(out))

print("----Data Saved.")
print("----------------")
EOF
```

**Check the file and the folders**

```bash
ls -la /mnt/data/benchmark/                                 # Check the file is created
wc -l /mnt/data/benchmark/prompts.jsonl                     # Count the lines of the new file.
```

![image8](/06-Benchmarking/Images/image8.png)

Expected: the line count is 5832, the same as the rows written. Both folders show the permissions `drwxrwxrwx`.

---

# Step-by-step

In this section we deploy the `GuideLLM` client, check that it works, and run the four tests: scenario A and scenario B, first for the original model and then for the tuned model.

> `kubectl` commands run on the laptop. The `GuideLLM` tests run inside the client pod, and the commands start them from the laptop.

## Step 1. Deploy the GuideLLM client

The client is one pod. It runs on a system node, so it does not take CPU from the `vLLM` servers. It uses the pinned image `ghcr.io/vllm-project/guidellm:v0.8.1`, and it mounts the shared filesystem at `/mnt/data`, so it can read the questions, read the key file and write the results. The pod asks for 3 CPUs and 4 GiB of memory, and it may use up to 6 CPUs and 8 GiB. Kubernetes places a pod by what it asks for, so the request must fit on the node. The limit lets the client use more CPU when the node has idle CPU. The container only sleeps. We start each test with a separate command.

> [!NOTE]
> The commands below run on the laptop.

**Choose a system node**

We must make sure that the client lands on a node with enough free resources (exampel; the client uses 3 CPUs). Use the command below to check the system nodes, and choose the node with the lowest usage.

```bash
# Show the requested CPU and memory of each system node.
kubectl describe nodes -l slurm.nebius.ai/nodeset=system | grep -E '^Name:|^  (cpu|memory) '
```

![image9](/06-Benchmarking/Images/image9.png)

Expected: the four system nodes, and for each node a `cpu` line and a `memory` line with the amount that is already requested. Choose the node with the lowest usage and save its name in a variable:

```bash
export NODE=<the name of the chosen system node>
```

**Create the pod**

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: guidellm-client
  namespace: soperator
  labels:
    app: guidellm-client
spec:
  restartPolicy: Never
  nodeSelector:
    kubernetes.io/hostname: $NODE
  containers:
  - name: guidellm
    image: ghcr.io/vllm-project/guidellm:v0.8.1
    imagePullPolicy: IfNotPresent
    command: ["sleep", "infinity"]
    resources:
      requests:
        cpu: "3"
        memory: 4Gi
      limits:
        cpu: "6"
        memory: 8Gi
    volumeMounts:
    - name: data
      mountPath: /mnt/data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: jail-submount-data-pvc
EOF
```

**Check the pod is running**


```bash
kubectl -n soperator get pod guidellm-client -o wide
```

![image10](/06-Benchmarking/Images/image10.png)

Expected: the pod `guidellm-client` shows `READY 1/1`, `STATUS Running` and `RESTARTS 0`. The `NODE` column shows the system node that you chose.

## Step 2. Run the tests

We run four tests, one after the other. Wait until a test ends before you start the next one. Close the `Open WebUI` tab before you start, and send no chat message until the last test is done.

All four commands have the same shape. We use the option `-it` of `kubectl exec`, so the console shows the live table of the sweep.

- `HOST`, `NAME` and `TAG` choose the server, the served model name and the name of the result files.
- `--backend` tells `GuideLLM` where to send the requests. The key comes from the key file inside the pod, so it never appears in a command or in a screenshot. `request_format=/v1/chat/completions` sends the messages as a chat. `extras.body.temperature=0` puts temperature 0 in every request.
- `--profile kind=sweep` runs the ladder of load levels.
- `--constraint kind=max_duration,seconds=30` limits every level to 30 seconds.
- `--data kind=json_file,path=...` reads our prompt file, and `--data-loader kind=pytorch,shuffle=false` keeps the order of the file.
- `--seed kind=static,value=42` fixes the random choices.
- `--output` writes a JSON file and a CSV file to `/mnt/data/benchmark/results`.

### Test 1: the original model, scenario A (natural answers)

The original model writes its natural answer to every question. This test shows what a user of the original model feels.

```bash
kubectl -n soperator exec -it guidellm-client -- env HOST=vllm-qwen-base NAME=Qwen-Base TAG=base sh -c '
mkdir -p /mnt/data/benchmark/results; KEYV=$(cat /mnt/data/secrets/vllm.key)
guidellm run \
  --backend "kind=openai_http,target=http://$HOST:8000,model=$NAME,request_format=/v1/chat/completions,api_key=$KEYV,extras.body.temperature=0" \
  --profile kind=sweep \
  --constraint kind=max_duration,seconds=30 \
  --data kind=json_file,path=/mnt/data/benchmark/prompts.jsonl \
  --data-loader kind=pytorch,shuffle=false \
  --seed kind=static,value=42 \
  --output kind=json,path=/mnt/data/benchmark/results/${TAG}_A.json \
  --output kind=csv,path=/mnt/data/benchmark/results/${TAG}_A.csv'
```

![image11](/06-Benchmarking/Images/image11.png)

Expected: GuideLLM prints several tables, then the line `Benchmarking complete, generated 10 benchmark(s)` and the paths of two result files, `base_A.json` and `base_A.csv`.

While the test is running, GuideLLM shows a live table with one row for each level of the sweep. You can use it to follow the progress: which level is running, how many requests per second the server handles, how long a request takes, and whether any request fails.

![image12](/06-Benchmarking/Images/image12.png)

These are the tables from this output:

**Run Summary Info.** What happened in each of the 10 levels: the start and end time, how many requests completed, how many were still running at the end, and how many failed. It also counts the input and output tokens. We use it to see that the test is clean, because the `Err` column must be 0.

![image13](/06-Benchmarking/Images/image13.png)

**Text Metrics Statistics.** The size of the questions and of the answers, in tokens, words and characters. It shows the size per request, as the median and the p95, and per second, as the median and the mean.

![image14](/06-Benchmarking/Images/image14.png)

**Request Token Statistics.** The number of tokens in one request: the question, the answer and the total. It shows the median and the p95. We use it to see the length of the answers.

![image15](/06-Benchmarking/Images/image15.png)

**Request Latency Statistics.** The time of one request. It shows the total time of a request, the time to first token (TTFT), the time between two tokens (ITL), and the time per output token (TPOT). It shows the mean, the median and the p95. This is the main table for speed.

![image16](/06-Benchmarking/Images/image16.png)

**Server Throughput Statistics.** How much work the whole server does each second: the number of requests in flight, the requests per second, and the input, output and total tokens per second. This is the main table for performance.

![image17](/06-Benchmarking/Images/image17.png)

For the full details of each test, see the result files (CSV and JSON) in the [Outputs](/06-Benchmarking/Outputs) folder - (base_A.csv & base_A.json).

### Test 2: the tuned model, scenario A (natural answers)

The same test, now against the tuned model. The questions, the order and the settings are the same. Only the three values after `env` change.

```bash
kubectl -n soperator exec -it guidellm-client -- env HOST=vllm-qwen-tuned NAME=Qwen-Tuned TAG=tuned sh -c '
mkdir -p /mnt/data/benchmark/results; KEYV=$(cat /mnt/data/secrets/vllm.key)
guidellm run \
  --backend "kind=openai_http,target=http://$HOST:8000,model=$NAME,request_format=/v1/chat/completions,api_key=$KEYV,extras.body.temperature=0" \
  --profile kind=sweep \
  --constraint kind=max_duration,seconds=30 \
  --data kind=json_file,path=/mnt/data/benchmark/prompts.jsonl \
  --data-loader kind=pytorch,shuffle=false \
  --seed kind=static,value=42 \
  --output kind=json,path=/mnt/data/benchmark/results/${TAG}_A.json \
  --output kind=csv,path=/mnt/data/benchmark/results/${TAG}_A.csv'
```

![image18](/06-Benchmarking/Images/image18.png)

Expected: GuideLLM prints several tables, then the line `Benchmarking complete, generated 10 benchmark(s)` and the paths of two result files, `base_A.json` and `base_A.csv`.

While the test is running, GuideLLM shows a live table with one row for each level of the sweep. You can use it to follow the progress: which level is running, how many requests per second the server handles, how long a request takes, and whether any request fails.

![image19](/06-Benchmarking/Images/image19.png)

For the full details of each test, see the result files (CSV and JSON) in the [Outputs](/06-Benchmarking/Outputs) folder - (tuned_A.csv & tuned_A.json).

## Comparison of the two models for scenario A (natural answers)

The table compares the original model and the tuned model. The speed values (points 1 to 4) come from the `synchronous` level, where one request runs at a time, so no other request disturbs the result. The values for the full server (points 5 and 6) come from the `throughput` level, where the server is full.

| # | Measurement | Original (`Qwen-Base`) | Tuned (`Qwen-Tuned`) |
|---|---|---|---|
| 1 | TTFT, p50 | 13.1 ms | 12.4 ms |
| 1 | TTFT, p95 | 27.7 ms* | 14.8 ms |
| 2 | Inter-token latency (ITL), mean | 5.8 ms | 5.7 ms |
| 3 | Output length, median | 129 tokens | 32 tokens |
| 4 | End-to-end latency, p50 | 0.8 s | 0.2 s |
| 4 | End-to-end latency, p95 | 1.4 s* | 0.4 s |
| 5 | Output tokens per second at saturation | 16,936.9 | 7,305.1 |
| 6 | Requests per second at saturation | 117.6 | 234.5 |
| 8 | Failed requests, all 10 levels | 0 | 0 |
| 11 | Estimated TFLOPS at saturation | 565 (57% of the H100 peak) | 649 (66% of the H100 peak) |

\* `GuideLLM` marks this value because the sample of the `synchronous` level is small for the original model: 37 completed requests, against 142 for the tuned model.

The speed per token is the same for both models: the TTFT and the ITL differ by less than 1 ms. The difference is the length of the answer. The tuned model writes a median of 32 tokens, and the original model writes 129. So one answer takes 0.2 s instead of 0.8 s, and a full server finishes 234.5 answers per second instead of 117.6. The tuned model has fewer output tokens per second, because each of its answers is shorter.

**Latency against load (point 7)**

Each table shows the 8 `constant` levels of the sweep. The column `Done per second` is the number of requests that the server really finished each second.

Original model:

| Asked per second | Done per second | TTFT p50 (ms) | ITL p50 (ms) | Latency p50 (s) |
|---|---|---|---|---|
| 15.78 | 15.3 | 19.8 | 6.2 | 0.7 |
| 30.32 | 29.5 | 21.1 | 6.4 | 0.7 |
| 44.87 | 43.3 | 22.9 | 6.8 | 0.8 |
| 59.42 | 57.5 | 23.2 | 7.1 | 0.8 |
| 73.96 | 71.0 | 26.9 | 7.6 | 0.9 |
| 88.51 | 84.6 | 29.6 | 8.6 | 1.0 |
| 103.05 | 97.3 | 35.7 | 10.6 | 1.2 |
| 117.60 | 108.4 | 53.6 | 17.9 | 2.0 |

Tuned model:

| Asked per second | Done per second | TTFT p50 (ms) | ITL p50 (ms) | Latency p50 (s) |
|---|---|---|---|---|
| 33.46 | 33.2 | 19.6 | 6.1 | 0.2 |
| 62.18 | 61.7 | 19.9 | 6.3 | 0.2 |
| 90.91 | 90.3 | 21.4 | 6.5 | 0.2 |
| 119.64 | 118.8 | 21.9 | 6.9 | 0.2 |
| 148.36 | 147.1 | 24.8 | 7.7 | 0.2 |
| 177.09 | 175.4 | 30.5 | 9.6 | 0.3 |
| 205.81 | 203.2 | 45.2 | 15.1 | 0.4 |
| 234.54 | 228.3 | 107.1 | 37.4 | 1.0 |

At the three highest levels, the tuned model finished all 5,832 questions of the file before the 30 seconds ended. These levels ran 24.9 s (`throughput`), 28.7 s and 25.6 s. The two models also have different levels, because the sweep sets its levels from the highest rate that each server reached.

**Conclusion.** 

The tuned model lost no performance. Its speed per token is the same as the original model: the TTFT is 12.4 ms against 13.1 ms, and the ITL is 5.7 ms against 5.8 ms. It is better in the overall result, because it writes much shorter answers, a median of 32 tokens against 129. A full answer takes 0.2 s instead of 0.8 s, and the server finishes 234.5 answers per second instead of 117.6. Neither model had a failed request. The tuned model shows fewer output tokens per second (7,305.1 against 16,936.9), and this is not a loss, because each of its answers is shorter. This test measures speed and performance only. It does not measure the accuracy of the answers.


### Test 3: the original model, scenario B (equal answers)

Now both models must write exactly 128 tokens. The command uses the same questions, and it adds three settings to the backend: `max_tokens=128` and `max_completion_tokens=128` set the length, and `ignore_eos=true` tells `vLLM` to keep writing even after the model would stop. We set both token options, because we do not know which one the server uses for a chat request, and the same value in both cannot conflict.

```bash
kubectl -n soperator exec -it guidellm-client -- env HOST=vllm-qwen-base NAME=Qwen-Base TAG=base sh -c '
KEYV=$(cat /mnt/data/secrets/vllm.key)
guidellm run \
  --backend "kind=openai_http,target=http://$HOST:8000,model=$NAME,request_format=/v1/chat/completions,api_key=$KEYV,extras.body.temperature=0,extras.body.max_tokens=128,extras.body.max_completion_tokens=128,extras.body.ignore_eos=true" \
  --profile kind=sweep \
  --constraint kind=max_duration,seconds=30 \
  --data kind=json_file,path=/mnt/data/benchmark/prompts.jsonl \
  --data-loader kind=pytorch,shuffle=false \
  --seed kind=static,value=42 \
  --output kind=json,path=/mnt/data/benchmark/results/${TAG}_B.json \
  --output kind=csv,path=/mnt/data/benchmark/results/${TAG}_B.csv'
```

For the full details of each test, see the result files (CSV and JSON) in the [Outputs](/06-Benchmarking/Outputs) folder - (base_B.csv & base_B.json).

### Test 4: the tuned model, scenario B (equal answers)

The same as test 3, now against the tuned model. This is the test that proves the forced length. The tuned model would normally stop after a short SQL line, and here it must keep writing until 128 tokens.

```bash
kubectl -n soperator exec -it guidellm-client -- env HOST=vllm-qwen-tuned NAME=Qwen-Tuned TAG=tuned sh -c '
KEYV=$(cat /mnt/data/secrets/vllm.key)
guidellm run \
  --backend "kind=openai_http,target=http://$HOST:8000,model=$NAME,request_format=/v1/chat/completions,api_key=$KEYV,extras.body.temperature=0,extras.body.max_tokens=128,extras.body.max_completion_tokens=128,extras.body.ignore_eos=true" \
  --profile kind=sweep \
  --constraint kind=max_duration,seconds=30 \
  --data kind=json_file,path=/mnt/data/benchmark/prompts.jsonl \
  --data-loader kind=pytorch,shuffle=false \
  --seed kind=static,value=42 \
  --output kind=json,path=/mnt/data/benchmark/results/${TAG}_B.json \
  --output kind=csv,path=/mnt/data/benchmark/results/${TAG}_B.csv'
```

For the full details of each test, see the result files (CSV and JSON) in the [Outputs](/06-Benchmarking/Outputs) folder - (tuned_B.csv & tuned_B.json).

## Comparison of the two models for scenario B (equal answers)

In scenario B, both models write exactly 128 tokens for every question. The median and the p95 of the output length are 128.0 at every level, for both models. So the two models do the same work, and the table shows how fast the server does it. The speed values come from the `synchronous` level, and the values for the full server come from the `throughput` level.

| # | Measurement | Original (`Qwen-Base`) | Tuned (`Qwen-Tuned`) |
|---|---|---|---|
| 1 | TTFT, p50 | 12.9 ms | 13.2 ms |
| 1 | TTFT, p95 | 15.8 ms* | 15.4 ms* |
| 2 | Inter-token latency (ITL), mean | 5.9 ms | 5.9 ms |
| 3 | Output length, median | 128 tokens (forced) | 128 tokens (forced) |
| 4 | End-to-end latency, p50 | 0.8 s | 0.8 s |
| 4 | End-to-end latency, p95 | 0.8 s* | 0.8 s* |
| 5 | Output tokens per second at saturation | 17,473.3 | 17,489.9 |
| 6 | Requests per second at saturation | 130.6 | 133.2 |
| 8 | Failed requests, all 10 levels | 0 | 0 |
| 11 | Estimated TFLOPS at saturation | 590 (60% of the H100 peak) | 592 (60% of the H100 peak) |

\* `GuideLLM` marks this value because the sample of the `synchronous` level is small: 39 completed requests for each model.

**Latency against load (point 7)**

Each table shows the 8 `constant` levels of the sweep. The column `Done per second` is the number of requests that the server really finished each second.

Original model:

| Asked per second | Done per second | TTFT p50 (ms) | ITL p50 (ms) | Latency p50 (s) |
|---|---|---|---|---|
| 17.46 | 17.0 | 20.1 | 6.2 | 0.8 |
| 33.62 | 32.7 | 20.9 | 6.4 | 0.8 |
| 49.77 | 48.3 | 22.4 | 6.8 | 0.9 |
| 65.93 | 63.9 | 23.1 | 7.1 | 0.9 |
| 82.09 | 79.4 | 26.9 | 7.8 | 1.0 |
| 98.25 | 94.5 | 30.1 | 8.9 | 1.2 |
| 114.41 | 108.5 | 40.6 | 12.8 | 1.7 |
| 130.57 | 118.8 | 62.9 | 20.9 | 2.7 |

Tuned model:

| Asked per second | Done per second | TTFT p50 (ms) | ITL p50 (ms) | Latency p50 (s) |
|---|---|---|---|---|
| 17.78 | 17.3 | 20.1 | 6.2 | 0.8 |
| 34.27 | 33.3 | 20.9 | 6.4 | 0.8 |
| 50.75 | 49.3 | 22.2 | 6.8 | 0.9 |
| 67.23 | 65.2 | 23.6 | 7.2 | 0.9 |
| 83.72 | 80.9 | 27.1 | 7.8 | 1.0 |
| 100.20 | 96.2 | 30.6 | 9.0 | 1.2 |
| 116.68 | 110.3 | 41.8 | 13.1 | 1.7 |
| 133.17 | 119.8 | 69.0 | 23.1 | 3.0 |

**Conclusion.** 

With equal work, the two models perform the same. The TTFT and the ITL are the same, and the full server writes about 17,500 output tokens per second for both models. The requests per second differ by 2% (130.6 and 133.2), and the load tables follow each other at every level. Each test ran once, so we treat this as no difference. The tuned model lost no speed. In scenario A, the tuned model finishes more answers per second only because its answers are shorter.

---
