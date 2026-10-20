# 05 - Serve: Scripts and Commands

> Every script and main command used in the serving activity, in the order they were run. Each entry gives the name of the step, what it does, why we used it, a link to the section of the [Serve README](/05-Serve/README.md) that explains it, and the code itself.

---

# Summary

This is a summary of the file, with a link to each group of scripts.

* [A. Preparation](#a-preparation) - 5 scripts and commands. Runs on: laptop and Slurm login pod.
* [B. Step 1: Start the two vLLM servers](#b-step-1-start-the-two-vllm-servers) - 6 scripts and commands. Runs on: Slurm login pod.
* [C. Step 2: Give each server a stable name inside the cluster](#c-step-2-give-each-server-a-stable-name-inside-the-cluster) - 2 scripts and commands. Runs on: laptop.
* [D. Step 3: Deploy Open WebUI](#d-step-3-deploy-open-webui) - 3 scripts and commands. Runs on: Slurm login pod and laptop.
* [E. Step 4: Expose Open WebUI with one load balancer](#e-step-4-expose-open-webui-with-one-load-balancer) - 3 scripts and commands. Runs on: laptop.

---

# A. Preparation

## A1. Log in to the Slurm login pod (laptop)

- **What it does:** Sets the SSH key and the login pod address, and opens a shell on the login pod.
- **Why we used it:** The merge and the Slurm jobs are started from the login pod.
- **Section:** [Preparation](/05-Serve/README.md#preparation)

````bash
export KEY=~/.ssh/taher-soperator-demoday
export LOGIN_IP=$(kubectl -n soperator get svc soperator-login-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
ssh -i $KEY root@$LOGIN_IP
````

## A2. Check the adapter and the disk (login pod)

- **What it does:** Lists the 3-epoch adapter files and shows the free space on `/mnt/data`.
- **Why we used it:** The adapter must be in place, and the merged model needs about 15 GB.
- **Section:** [Preparation 1: Merge the adapter into the base model](/05-Serve/README.md#preparation-1-merge-the-adapter-into-the-base-model)

````bash
ls -lh /mnt/data/outputs/qwen25-7b-sql-lora-3ep
df -h /mnt/data
````

## A3. Merge the adapter into the base model (login pod)

- **What it does:** Runs `axolotl merge-lora` on one worker and writes the merged model to a `merged` folder.
- **Why we used it:** `vLLM` serves a normal model, so both servers run the same command and the benchmark is fair.
- **Section:** [Preparation 1: Merge the adapter into the base model](/05-Serve/README.md#preparation-1-merge-the-adapter-into-the-base-model)

````bash
export HF_HOME=/mnt/data/hf-cache
srun --nodes=1 --nodelist=worker-0 --gres=gpu:1 \
  --container-image=axolotlai/axolotl:main-20261013-py3.12-cu130-2.13.0 \
  --container-mounts=/mnt/data:/mnt/data \
  --container-env=HF_HOME \
  axolotl merge-lora /mnt/data/configs/lora-sql-qwen7b-3ep.yaml \
  2>&1 | tee /mnt/data/logs/merge-3ep.log
````

## A4. Check the merged model (login pod)

- **What it does:** Lists the files of the merged model.
- **Why we used it:** To confirm that the four shards, the config and the tokenizer files are there.
- **Section:** [Preparation 1: Merge the adapter into the base model](/05-Serve/README.md#preparation-1-merge-the-adapter-into-the-base-model)

````bash
ls -lh /mnt/data/outputs/qwen25-7b-sql-lora-3ep/merged
````

## A5. Create the API key (login pod)

- **What it does:** Creates a random key and saves it in `/mnt/data/secrets/vllm.key`.
- **Why we used it:** Both `vLLM` servers refuse requests that do not carry the key.
- **Section:** [Preparation 2: Create the API key](/05-Serve/README.md#preparation-2-create-the-api-key)

````bash
mkdir -p /mnt/data/secrets
openssl rand -hex 16 > /mnt/data/secrets/vllm.key
ls -l /mnt/data/secrets/vllm.key
````

---

# B. Step 1: Start the two vLLM servers

## B1. Create the serving folder

- **What it does:** Creates `/mnt/data/serve` for the job files.
- **Why we used it:** The two `sbatch` files need one known place on the shared disk.
- **Section:** [Step 1. Start the two vLLM servers](/05-Serve/README.md#step-1-start-the-two-vllm-servers)

````bash
mkdir -p /mnt/data/serve
````

## B2. Create the `sbatch` file for `Qwen-Base`

- **What it does:** Writes the Slurm job that serves the original model on `worker-0`.
- **Why we used it:** `vLLM` runs as a Slurm job inside a container, the same way as the fine-tune.
- **Section:** [Step 1. Start the two vLLM servers](/05-Serve/README.md#step-1-start-the-two-vllm-servers)

````bash
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
````

## B3. Create the `sbatch` file for `Qwen-Tuned`

- **What it does:** Writes the Slurm job that serves the merged model on `worker-1`.
- **Why we used it:** It is the same command as the base job. Only the node, the model and the served name differ.
- **Section:** [Step 1. Start the two vLLM servers](/05-Serve/README.md#step-1-start-the-two-vllm-servers)

````bash
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
````

## B4. Check that both files are created

- **What it does:** Lists the files in `/mnt/data/serve`.
- **Why we used it:** To confirm that both job files exist before we submit them.
- **Section:** [Step 1. Start the two vLLM servers](/05-Serve/README.md#step-1-start-the-two-vllm-servers)

````bash
ls -lh /mnt/data/serve/
````

## B5. Submit both jobs

- **What it does:** Submits the two jobs and shows them in the queue.
- **Why we used it:** This starts the two `vLLM` servers.
- **Section:** [Step 1. Start the two vLLM servers](/05-Serve/README.md#step-1-start-the-two-vllm-servers)

````bash
sbatch /mnt/data/serve/serve-qwen-base.sbatch
sbatch /mnt/data/serve/serve-qwen-tuned.sbatch
squeue
````

## B6. Follow the server log

- **What it does:** Prints the log of a job as it grows.
- **Why we used it:** To see the model load and to wait for `Application startup complete`.
- **Section:** [Step 1. Start the two vLLM servers](/05-Serve/README.md#step-1-start-the-two-vllm-servers)

````bash
tail -f /mnt/data/logs/vllm-original-<JOBID>.log
````

---

# C. Step 2: Give each server a stable name inside the cluster

## C1. Create the two ClusterIP Services

- **What it does:** Creates `vllm-qwen-base` and `vllm-qwen-tuned`, each pointing at one worker pod.
- **Why we used it:** A pod IP changes after a restart, and a Service name does not.
- **Section:** [Step 2. Give each server a stable name inside the cluster](/05-Serve/README.md#step-2-give-each-server-a-stable-name-inside-the-cluster)

````bash
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
````

## C2. Check the Services and their endpoints

- **What it does:** Shows the Services, their endpoints and the worker pods.
- **Why we used it:** To confirm that each Service points at the right worker.
- **Section:** [Step 2. Give each server a stable name inside the cluster](/05-Serve/README.md#step-2-give-each-server-a-stable-name-inside-the-cluster)

````bash
kubectl -n soperator get svc vllm-qwen-base vllm-qwen-tuned
kubectl -n soperator get endpoints vllm-qwen-base vllm-qwen-tuned
kubectl -n soperator get pod worker-0 worker-1 -o wide
````

---

# D. Step 3: Deploy Open WebUI

## D1. Save the API key in a variable

- **What it does:** Puts the API key in a shell variable.
- **Why we used it:** The `Open WebUI` deployment uses the key to call both servers.
- **Section:** [Step 3. Deploy Open WebUI](/05-Serve/README.md#step-3-deploy-open-webui)

````bash
KEY="<paste the API key here>"
````

## D2. Deploy Open WebUI (laptop)

- **What it does:** Creates one `Open WebUI` pod on a system node, connected to both servers by name.
- **Why we used it:** One chat page with a dropdown lets us ask both models the same question.
- **Section:** [Step 3. Deploy Open WebUI](/05-Serve/README.md#step-3-deploy-open-webui)

````bash
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
````

## D3. Check the deployment (laptop)

- **What it does:** Waits for the rollout and shows the pod.
- **Why we used it:** To confirm that the pod runs on a system node and is ready.
- **Section:** [Step 3. Deploy Open WebUI](/05-Serve/README.md#step-3-deploy-open-webui)

````bash
kubectl -n soperator rollout status deployment/open-webui
kubectl -n soperator get pods -l app=open-webui -o wide
````

---

# E. Step 4: Expose Open WebUI with one load balancer

## E1. Create the LoadBalancer Service

- **What it does:** Creates a Service that gives `Open WebUI` a public IP.
- **Why we used it:** It is the only public door. The `vLLM` servers stay internal.
- **Section:** [Step 4. Expose Open WebUI with one load balancer](/05-Serve/README.md#step-4-expose-open-webui-with-one-load-balancer)

````bash
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
````

## E2. Get the public IP

- **What it does:** Shows the Service and its `EXTERNAL-IP`.
- **Why we used it:** We need the IP to open the chat page.
- **Section:** [Step 4. Expose Open WebUI with one load balancer](/05-Serve/README.md#step-4-expose-open-webui-with-one-load-balancer)

````bash
kubectl -n soperator get svc open-webui-lb
````

## E3. Test the page from outside

- **What it does:** Sends one request to the public IP and prints the HTTP code.
- **Why we used it:** To confirm that the page answers from outside the cluster.
- **Section:** [Step 4. Expose Open WebUI with one load balancer](/05-Serve/README.md#step-4-expose-open-webui-with-one-load-balancer)

````bash
curl -s -o /dev/null -w "%{http_code}\n" http://<LB-IP>/
````

---
