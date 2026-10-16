# 05 - Serve

> Serving the original and the fine-tuned `Qwen2.5-7B-Instruct` with `vLLM` on the two Soperator worker nodes, and reaching both models from the internet through one `Open WebUI` chat page behind a single Kubernetes load balancer.

---

# Description

# Description

This section holds everything needed to serve the fine-tuned model built in [04-Fine-Tuning](/04-Fine-Tune/README.md) on the Soperator cluster built in [03-Provision](/03-Provision/README.md).

It covers task 2 of the Nebius Demo Day: serve the trained model for inference on the same Kubernetes cluster.

We serve two models with `vLLM`. Each one runs on its own Slurm worker node, with its own H100 GPU:
- **original:** the base model, `Qwen/Qwen2.5-7B-Instruct`, on `worker-0`.
- **tuned:** the same base model with the LoRA adapter from 04 merged into it, on `worker-1`.

We will merge the LoRA adapter from [04-Fine-Tuning](/04-Fine-Tune/README.md) into the base model, which gives us a full tuned model. Then we serve both models with `vLLM`. `vLLM` is the server that loads a model into the GPU and answers requests over an OpenAI-compatible API. The tuned model runs on one Slurm worker node, and the base model runs on the other. Axolotl is used once, for the merge. A merged model is a normal model, so both servers run the same command, and the tuned model carries no extra adapter load. This keeps the later benchmark fair.

When both servers run, we deploy `Open WebUI`, a web chat page. It connects to both servers and shows them in one dropdown, so you can ask the same question to both models and compare the answers.

The section gives the strategy and the reasons behind it, with a short explanation of each tool. Then it gives one preparation step, which is the merge, and a step-by-step guide with every command.

**The infrastructure in short**

For full details, please refer to [03-Provision](/03-Provision/README.md).

- **`worker-0`:** a Slurm worker pod on a GPU node, with one H100. It serves the original model.
- **`worker-1`:** the same, with one H100. It serves the tuned model.
- **Slurm login:** a pod on a system node. We use it to submit the `vLLM` jobs and to test the servers from inside the cluster.
- **System nodes:** CPU nodes that host the cluster services. `Open WebUI` runs here, because it needs no GPU.
- **Shared filesystem:** mounted on all nodes at `/mnt/data`. It holds the base model, the adapter, the merged model, the logs and the key file. Both workers read the same files.

---

# Strategy and why

## The limitation that shapes the plan

The task is to serve the tuned model on the same Kubernetes cluster. The cluster has only two GPU nodes, and both already host the Slurm workers, `worker-0` and `worker-1`. The GPUs belong to Slurm, so there is no free GPU for a separate Kubernetes deployment. We have three options:

| Option | What it means | Cost |
|---|---|---|
| Patch Soperator to remove one worker | One GPU node is freed for Kubernetes and serves the tuned model. | There is no second GPU for the base model, so we cannot serve both. |
| Patch Soperator to remove both workers | Both GPU nodes are freed and serve both models as normal Kubernetes workloads. | The Slurm workers disappear completely. This is untested, and it can break the cluster we built in 03. |
| **Serve both models on the Slurm workers** | `vLLM` runs as a Slurm job on each worker. | The GPUs stay under Slurm control, so the jobs have a time limit and we must stop training before we serve. |

We use the third option. It changes nothing in Soperator, it uses the same Slurm, Pyxis and Enroot tools that already ran the fine-tune, and it gives each model a full H100.

## Serving the models with vLLM

We use `vLLM` as the inference server for both models. It loads a model into the GPU and answers requests over an OpenAI-compatible API on port 8000. It batches requests continuously, so the GPU stays busy when several requests arrive at once. Any client that speaks the OpenAI format can use it, including `Open WebUI` and a benchmark script.

We host one server on each Slurm worker. `worker-0` serves the original model. `worker-1` serves the tuned model. Each server runs as an `sbatch` job inside an Enroot container, from a pinned `vLLM` image. The log goes to `/mnt/data/logs`.

## Merging the adapter first

The fine-tune produced a small LoRA adapter, not a full model. `vLLM` can serve an adapter on top of the base model, but this adds a small extra calculation on every token. We do not want this load in the benchmark.

So, before serving, we merge the adapter into the base model with Axolotl. The result is a full tuned model on `/mnt/data`. To `vLLM` it is a normal model. Both servers then run the same command, and only the model path and the served name are different. The two models are compared on equal terms.

The cost is the merge itself: some time, and about 15 GB of extra disk on `/mnt/data`.

## Exposing the models: the network path

The next problem is how a person reaches the models from outside. The cluster can create `LoadBalancer` Services, and the login pod already uses one. But the two worker nodes carry the label `node.kubernetes.io/exclude-from-external-load-balancers=true`, which excludes them from external load balancers. A public Service that points straight at a worker pod may therefore get no working backend. We have two ways around this:

| Option | What it means | Cost |
|---|---|---|
| Remove the label from the worker nodes | The workers can be load balancer backends. | We change the nodes, and the change may be undone when the node group is updated. We need two public IPs, one for each model. |
| **Keep the nodes as they are** | Two internal `ClusterIP` Services give the workers stable names. One `Open WebUI` pod on a system node, which can use a load balancer, is the only public door. | The models are reachable from outside only through the chat page. |

We use the second option. It needs no change to the nodes, and it needs only one public IP. It also gives the demo what it needs: one page with a dropdown to pick a model.

**How the pieces connect**

1. `vLLM` listens on port 8000 on each worker pod. We expect Enroot to share the pod network, so the port appears on the pod IP `[TO VERIFY]`. This is the first thing we test.
2. Two `ClusterIP` Services point at the worker pods by label: `vllm-original` points at `worker-0`, and `vllm-tuned` points at `worker-1`. They have no public IP.
3. One `Open WebUI` pod runs on a system node. It calls `vllm-original` and `vllm-tuned` by name.
4. One `LoadBalancer` Service exposes only the `Open WebUI` pod. This is the one public IP.

The browser only talks to `Open WebUI`. It never talks to `vLLM`.

## Key decisions

| Decision | Choice | Why |
|---|---|---|
| Where the models run | The two **Slurm workers**, one model on each | The cluster has two GPU nodes, and Slurm owns them. Nothing in Soperator changes. |
| Model server | **vLLM**, OpenAI-compatible API on port 8000 | Continuous batching keeps the GPU busy. The OpenAI format works with `Open WebUI` and with a script. |
| How it runs | `sbatch` job in an Enroot container | The same tools that ran the fine-tune. The job has a time limit and a log in `/mnt/data/logs`. |
| Image | A pinned, dated `vLLM` image tag | Every rerun gets the same software. We do not use `latest`. |
| Tuned model | Adapter **merged** into the base model with Axolotl | Both servers run the same command, with no adapter load in the benchmark. |
| Names inside the cluster | Two `ClusterIP` Services selected by pod-name label | A pod IP changes after a restart. A Service name does not. |
| Public access | **One** `LoadBalancer` Service for `Open WebUI` on a system node | No change to the worker nodes, and only one public IP to protect. |
| Security | `vLLM --api-key`, an `Open WebUI` admin login, sign-up locked | A public page without a login lets anyone use the GPUs. |

## The tools

| Layer | Tool | What it does here |
|---|---|---|
| Scheduler | Slurm, run by Soperator | Gives each `vLLM` job one GPU, a time limit and a log file. |
| Container runtime | Pyxis and Enroot | Runs the `vLLM` image on the worker, with `/mnt/data` mounted. |
| Merge | Axolotl | Merges the LoRA adapter into the base model, once. |
| Model server | `vLLM` | Loads a model into the GPU and answers requests over an OpenAI-compatible API. |
| Internal names | Kubernetes `ClusterIP` Services | Give each worker a stable name inside the cluster. |
| Chat page | `Open WebUI` | A web page with a model dropdown. It is only a client and needs no GPU. |
| Public access | Kubernetes `LoadBalancer` Service | Gives the chat page one public IP. |

`Open WebUI` connects to one or more OpenAI-compatible servers and lists their models in one dropdown. It keeps its own users and chat history. It only sends requests, so it runs on a system node.

---

# The new tools

Two tools in this section are new to the project: `vLLM` and `Open WebUI`. This part explains what each one is and how we use it.

## vLLM

`vLLM` is an inference server. A training job reads data, learns and stops. A server stays on and answers requests all day. This changes what matters. In training we care about the total time. In serving we care about how many requests we answer at once, and how fast each one comes back.

Its main idea is continuous batching. A simple server waits for a group of requests, runs them together and only then starts the next group. If one answer is long, the GPU waits for it. With `vLLM`, a new request joins the batch that is already running, and a finished request leaves it. The H100 stays busy. `vLLM` also manages the GPU memory of each running request with care, so more requests fit on one card.

It exposes the OpenAI API format, with routes such as `/v1/models` and `/v1/chat/completions`. Any client that speaks this format can use it, without special code. It can also ask for an API key, so only clients that hold the key can use the GPU.

**How we use it.** We run two `vLLM` servers, one on each Slurm worker. Each one is a Slurm job inside a container, and each loads one model into its own H100. The original server runs on `worker-0` and the tuned server runs on `worker-1`. Both start in the same way. Only the model and the served name are different, so the original model answers to the name `original`, and the tuned model answers to the name `tuned`. Both servers ask for an API key. Two clients call them: `Open WebUI` for the live demo, and a script for the benchmark in 06.

## Open WebUI

`Open WebUI` is a web chat page. It connects to one or more OpenAI-compatible servers and lists their models in one dropdown. The user picks a model, types a question and reads the answer. It keeps its own users, logins and chat history. Because it only sends requests and shows answers, it does not need a GPU.

**How we use it.** We run one `Open WebUI` pod on a system node, where it has no effect on the GPU workers. We point it at the two servers by their internal names, `vllm-original` and `vllm-tuned`. Both models then appear in the same dropdown. We can ask the same question to both and compare the answers side by side. It is also the only public door in this section: one load balancer exposes it, and nothing else. We create the admin account first and then close sign-up, so only we can log in.

It is for the live demo only. It adds its own defaults to a request, so the benchmark does not use it. The benchmark calls the two servers directly.

---

# Preparation

Before we serve the models, we do two preparation tasks:

- **Preparation 1:** merge the LoRA adapter into the base model, to get the tuned model.
- **Preparation 2:** create the API key that protects the `vLLM` servers.

> [!NOTE]
> The commands below run on the Slurm login pod, and not on the laptop. Go to the terminal that is logged in to the login pod before you run them.
> If you are not logged in to th eslurm login, use the below commands to login
>
> ```bash
> export KEY=~/.ssh/taher-soperator-demoday
> export LOGIN_IP=$(kubectl -n soperator get svc soperator-login-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
> ```
>

## Preparation 1: Merge the adapter into the base model

The fine-tune in 04 produced a small LoRA adapter, not a full model. Before serving, we merge the adapter into the base model. The result is a full tuned model on `/mnt/data`, which `vLLM` loads like any other model, without an adapter. We do this once.

In 04 we ran two fine-tunes: one with 1 epoch and one with 3 epochs. In this activity we use the 3-epoch adapter, `qwen25-7b-sql-lora-3ep`, as it showed better tuning results.

We use `Axolotl` for the merge, because it already ran the training. `axolotl merge-lora` reads the same config file that trained the adapter. The config names the base model and the `output_dir`. The merge reads the adapter from `output_dir` and writes the merged model to a `merged` folder inside it:

```
/mnt/data/outputs/qwen25-7b-sql-lora-3ep/merged
```

The merge only adds new files. It does not change the adapter or the base model.

**Check the adapter and the disk**

First, we check that the adapter from the fine-tune is in place, and that the disk has room for the merged model, which is about 15 GB.

```bash
ls -lh /mnt/data/outputs/qwen25-7b-sql-lora-3ep
df -h /mnt/data
```

Expected: the files `adapter_model.safetensors` (about 155 MB) and `adapter_config.json`, the tokenizer files and the `checkpoint-` folders. In the `df` output, the `Avail` column shows more than 15 GB.

**Run the merge**

We run the merge on one worker, because it needs one GPU. It runs inside the same `Axolotl` image that ran the training, with `/mnt/data` mounted. We point `HF_HOME` to the shared cache, so the base model is read from `/mnt/data/hf-cache` and is not downloaded again. `--container-env` passes the variable into the container. The log is saved to a file, so we can read it again later.

```bash
export HF_HOME=/mnt/data/hf-cache
srun --nodes=1 --nodelist=worker-0 --gres=gpu:1 \
  --container-image=axolotlai/axolotl:main-20261013-py3.12-cu130-2.13.0 \
  --container-mounts=/mnt/data:/mnt/data \
  --container-env=HF_HOME \
  axolotl merge-lora /mnt/data/configs/lora-sql-qwen7b-3ep.yaml \
  2>&1 | tee /mnt/data/logs/merge-3ep.log
```

![image1](/05-Serve/Images/image1.png)

The merge takes about 1 to 2 minutes. The log shows the base model read from the cache, the four shards merged one by one, and the number of layers that got the adapter.

Expected: `Fetching 14 files: 14/14` finishing in under a second, because the base model comes from the cache. Then `Merging shards: 4/4`. Then `Applied LoRA to 196/339 tensors`. Qwen2.5-7B has 28 layers with 7 linear layers each (q, k, v, o, gate, up and down), and 28 × 7 = 196, so every adapter layer was merged. The other 143 tensors are embeddings, norms and biases, which have no adapter.

**Check the merged model**

```bash
ls -lh /mnt/data/outputs/qwen25-7b-sql-lora-3ep/merged
```

![image2](/05-Serve/Images/image2.png)

Expected: four `model-0000X-of-00004.safetensors` shards of about 3.4 to 3.7 GB each, `model.safetensors.index.json`, `config.json`, `generation_config.json` and the tokenizer files (`tokenizer.json`, `tokenizer_config.json`, `vocab.json`, `merges.txt`). The first line of the output reads `total 15G`, which is right for a 7.6-billion-parameter model in bf16 (2 bytes per parameter). The merge copies the tokenizer files, the config, the `LICENSE` and the `README.md` from the base model, so nothing needs to be copied by hand.

The folder `/mnt/data/outputs/qwen25-7b-sql-lora-3ep/merged` is the tuned model.

## Preparation 2: Create the API key

Both `vLLM` servers listen on port 8000 inside the cluster, and any pod in the cluster can reach them. The `soperator` namespace has no network policy that stops this. So each server asks for an API key, and refuses requests that do not carry it. The same key is used by `Open WebUI` when it calls the servers.

We create one key and keep it in a file on the shared filesystem, where the `vLLM` jobs read it when they start. We use `openssl` to create the key.

```bash
mkdir -p /mnt/data/secrets
openssl rand -hex 16 > /mnt/data/secrets/vllm.key
ls -l /mnt/data/secrets/vllm.key
```

![image3](/05-Serve/Images/image3.png)

Expected: the file vllm.key with the permissions -rw-r--r-- and a size of 33 bytes (32 characters and a new line). The command does not print the key. To read it, run `cat /mnt/data/secrets/vllm.key`.

---

# Step-by-step

In this section we start the two `vLLM` servers on the Slurm workers, give each one an internal name, put `Open WebUI` in front of them, and compare the two models in the chat page.

> Slurm commands run on the login node. `kubectl` commands run from your laptop.

## Step 1. Start the two vLLM servers

Each server is a Slurm job that runs the `vLLM` image on one worker and keeps running. Both jobs use the same command. Only the node, the model and the served name are different. The original model is read from the Hugging Face cache, and the tuned model is read from the merged folder from Preparation 1.

The key is read from the file we made in Preparation 2. `--served-model-name` sets the name that clients use: `Qwen-Base` or `Qwen-Tuned`. `--max-model-len 4096` is enough for the prompts in this dataset, where the longest has 715 tokens. `--gpu-memory-utilization 0.90` lets `vLLM` use 90% of the H100 memory. The partitions have no time limit (`MaxTime=INFINITE`), so we set the jobs to run without one. The models run until we stop them.

> [!NOTE]
> The commands below run on the Slurm login pod, and not on the laptop. Go to the terminal that is logged in to the login pod before you run them.
> If you are not logged in to th eslurm login, use the below commands to login
>
> ```bash
> export KEY=~/.ssh/taher-soperator-demoday
> export LOGIN_IP=$(kubectl -n soperator get svc soperator-login-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
> ```
>

**Create folder to hold the serving configuration file to be used**

```bash
mkdir -p /mnt/data/serve
```

**Create the sbatch file for the `Qwen-Base`**

```bash
cat > /mnt/data/serve/serve-qwen-base.sbatch <<'EOF'
#!/bin/bash
#SBATCH --job-name=vllm-original
#SBATCH --nodes=1
#SBATCH --nodelist=worker-0
#SBATCH --gres=gpu:1
#SBATCH --time=UNLIMITED
#SBATCH --output=/mnt/data/logs/vllm-original-%j.log

export HF_HOME=/mnt/data/hf-cache
VLLM_API_KEY=$(cat /mnt/data/secrets/vllm.key)

srun --container-image=vllm/vllm-openai:v0.31.0 \
  --container-mounts=/mnt/data:/mnt/data \
  --container-env=HF_HOME \
  vllm serve Qwen/Qwen2.5-7B-Instruct \
    --served-model-name Qwen-Base \
    --host 0.0.0.0 --port 8000 \
    --api-key "$VLLM_API_KEY" \
    --max-model-len 4096 --gpu-memory-utilization 0.90 --generation-config vllm
EOF
```

**Create the sbatch file for the `Qwen-Tuned`**

```bash
cat > /mnt/data/serve/serve-qwen-tuned.sbatch <<'EOF'
#!/bin/bash
#SBATCH --job-name=vllm-tuned
#SBATCH --nodes=1
#SBATCH --nodelist=worker-1
#SBATCH --gres=gpu:1
#SBATCH --time=UNLIMITED
#SBATCH --output=/mnt/data/logs/vllm-tuned-%j.log

export HF_HOME=/mnt/data/hf-cache
VLLM_API_KEY=$(cat /mnt/data/secrets/vllm.key)

srun --container-image=vllm/vllm-openai:v0.31.0 \
  --container-mounts=/mnt/data:/mnt/data \
  --container-env=HF_HOME \
  vllm serve /mnt/data/outputs/qwen25-7b-sql-lora-3ep/merged \
    --served-model-name Qwen-Tuned \
    --host 0.0.0.0 --port 8000 \
    --api-key "$VLLM_API_KEY" \
    --max-model-len 4096 --gpu-memory-utilization 0.90 --generation-config vllm
EOF
```

**Check both files are created**

```bash
ls -lh /mnt/data/serve/
```

![image4](/05-Serve/Images/image4.png)

Expected: the two job scripts, `serve-qwen-base.sbatch` and `serve-qwen-tuned.sbatch`, each about 600 bytes.

**Run Slurm jobs to serve both models**

```bash
sbatch /mnt/data/serve/serve-qwen-base.sbatch
sbatch /mnt/data/serve/serve-qwen-tuned.sbatch
squeue
```

![image5](/05-Serve/Images/image5.png)

Expected: `sbatch` prints `Submitted batch job <number>` for each script. `squeue` then shows both jobs in state `R`: `vllm-original` on `worker-0` and `vllm-tuned` on `worker-1`. The `NAME` column cuts names at 8 characters, so you see `vllm-ori` and `vllm-tun`.

The first start takes a few minutes, because Pyxis imports the image and `vLLM` loads the model into the GPU. We follow the log of each job until the server is ready. Replace `<JOBID>` with the job number from `squeue`.

```bash
tail -f /mnt/data/logs/vllm-original-<JOBID>.log
```

![image6](/05-Serve/Images/image6.png)

Expected: the log shows `served_model_name=Qwen-Base` in the engine start line, the weights loading in a few seconds (`Model loading took 14.29 GiB memory`), and the list of routes, including `/v1/models` and `/v1/chat/completions`. The log ends with `Starting vLLM server on http://0.0.0.0:8000` and `Application startup complete.`

## Step 2. Give each server a stable name inside the cluster

A pod IP changes when the pod restarts, so we create one `ClusterIP` Service for each worker. A Service is a saved label query. Each one selects one worker pod by its pod-name label, and gives it a fixed name inside the cluster. These Services have no public IP. The existing Service `soperator-nodeset-worker-svc` is not changed, because we select by a different label and use a different port.

> [!NOTE]
> The commands below run on the laptop, and not on the Slurm login pod. Go to the terminal on your laptop used to access kubectl before you run them.
> If your kucectl is not working - login to nebius and access the managed kubernetes cluster and then click on `how to connect`

**Create the 2 ClusterIP service to connect to the worker nodes**

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: vllm-qwen-base
  namespace: soperator
spec:
  type: ClusterIP
  selector:
    statefulset.kubernetes.io/pod-name: worker-0
  ports:
  - port: 8000
    targetPort: 8000
---
apiVersion: v1
kind: Service
metadata:
  name: vllm-qwen-tuned
  namespace: soperator
spec:
  type: ClusterIP
  selector:
    statefulset.kubernetes.io/pod-name: worker-1
  ports:
  - port: 8000
    targetPort: 8000
EOF
```

**Check the Services and their endpoints**

```bash
kubectl -n soperator get svc vllm-qwen-base vllm-qwen-tuned
kubectl -n soperator get endpoints vllm-qwen-base vllm-qwen-tuned
kubectl -n soperator get pod worker-0 worker-1 -o wide
```

![image7](/05-Serve/Images/image7.png)

Expected: both Services are `ClusterIP` with no external IP and port `8000/TCP`, and each one has a single endpoint ending in `:8000` which matches the IP of its worker pod: `vllm-qwen-base` to `worker-0` and `vllm-qwen-tuned` to `worker-1`.

## Step 3. Deploy Open WebUI

`Open WebUI` runs as one pod on a system node. It reads the two `vLLM` servers from `OPENAI_API_BASE_URLS` by their Service names, and the API key for each one from `OPENAI_API_KEYS`. Both lists use `;` as the separator. `ENABLE_TITLE_GENERATION` is off, so it does not send an extra request to the model for every chat title. The data is kept in an `emptyDir` volume, which is enough for a demo.

First, we put the API key in a shell variable. We take the value from `cat /mnt/data/secrets/vllm.key` on the login node. Then we deploy `Open WebUI` and wait until it is ready.

> [!NOTE] - Only the below command runs on the slurm login pod so you need to go to the login terminal - rest run on laptop

```bash
KEY="<paste the API key here>"
```

> [!NOTE]
> The commands below run on the laptop, and not on the Slurm login pod. Go to the terminal on your laptop used to access kubectl before you run them.
> If your kucectl is not working - login to nebius and access the managed kubernetes cluster and then click on `how to connect`

**Deploy the OpenWebUI**

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: open-webui
  namespace: soperator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: open-webui
  template:
    metadata:
      labels:
        app: open-webui
    spec:
      nodeSelector:
        slurm.nebius.ai/nodeset: system
      containers:
      - name: open-webui
        image: ghcr.io/open-webui/open-webui:v0.12.2
        ports:
        - containerPort: 8080
        env:
        - name: OPENAI_API_BASE_URLS
          value: "http://vllm-qwen-base:8000/v1;http://vllm-qwen-tuned:8000/v1"
        - name: OPENAI_API_KEYS
          value: "$KEY;$KEY"
        - name: ENABLE_TITLE_GENERATION
          value: "false"
        volumeMounts:
        - name: data
          mountPath: /app/backend/data
      volumes:
      - name: data
        emptyDir: {}
EOF
```

**Check deployment is successful**

```bash
kubectl -n soperator rollout status deployment/open-webui
kubectl -n soperator get pods -l app=open-webui -o wide
```

![image8](/05-Serve/Images/image8.png)

Expected: `rollout status` prints `deployment "open-webui" successfully rolled out`, and the pod is `Running` with `1/1` ready on a system node, not on `worker-0` or `worker-1`.

## Step 4. Expose Open WebUI with one load balancer

This is the only public address in the setup. The `LoadBalancer` Service points only at the `Open WebUI` pod. The `vLLM` servers stay internal. The cluster gives the Service a public IP.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: open-webui-lb
  namespace: soperator
spec:
  type: LoadBalancer
  selector:
    app: open-webui
  ports:
  - port: 80
    targetPort: 8080
EOF
```

```bash
kubectl -n soperator get svc open-webui-lb
```

![image9](/05-Serve/Images/image9.png)

Expected: the `open-webui-lb` Service is type `LoadBalancer`, and `EXTERNAL-IP` shows a public address, not `<pending>`. `PORT(S)` shows `80:` followed by a node port, as in `80:31684/TCP`.

Then we test it from outside the cluster:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://<LB-IP>/
```

![image10](/05-Serve/Images/image10.png)

Expected: `200`.

## Step 5. Log in and compare the models

Open `http://<LB-IP>` in a browser. The first account created on `Open WebUI` becomes the admin, so we create it now, before anyone else can. 

Right after, we close sign-up, so nobody else can create an account: **Admin Panel → System → Authentication → turn off "New Sign Ups"**.

![image11](/05-Serve/Images/image11.png)

Before the first question, we set **Function Calling** to **Legacy** for each model: **Admin Panel → Settings → Models → pencil icon → Advanced Params → Function Calling → Legacy**. --> With the default mode, `Open WebUI` asks `vLLM` to choose tools on its own, and `vLLM` refuses the request because we did not start it with tool support.

**`Open WebUI` is now up and connected to both models. Let us compare their answers with one example.**

1. Open `Open WebUI` in two browser tabs and log in.
2. In the first tab, select `Qwen-Base` in the dropdown below the chat box. In the second tab, select `Qwen-Tuned`.
3. In each tab, paste the same question in the chat box and check the output of each model. For example: `What is the average number of publications per researcher for researchers working at the 'National Geographic' organization?`

**Base Model**

![image12](/05-Serve/Images/image12.png)

**Tuned Model**

![image13](/05-Serve/Images/image13.png)

Expected: `Qwen-Base` answers in plain text. It explains that it needs more information and gives no SQL query. `Qwen-Tuned` answers with only a SQL query, with no explanation. Its answer has the same form as the expected output in the test dataset.

---





