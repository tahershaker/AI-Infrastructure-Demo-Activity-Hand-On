# 06 - Benchmarking: Scripts and Commands

> Every script and main command used in the benchmarking activity, in the order they were run. Each entry gives the name of the step, what it does, why we used it, a link to the section of the [Benchmarking README](/06-Benchmarking/README.md) that explains it, and the code itself.

---

# Summary

This is a summary of the file, with a link to each group of scripts.

* [A. Preparation 1: Suspend the `enroot-cleanup` health check](#a-preparation-1-suspend-the-enroot-cleanup-health-check) - 3 scripts and commands. Runs on: laptop and Slurm login pod.
* [B. Preparation 2: More CPU and API processes for vLLM, and restart](#b-preparation-2-more-cpu-and-api-processes-for-vllm-and-restart) - 7 scripts and commands. Runs on: Slurm login pod.
* [C. Preparation 3: Build the prompt file](#c-preparation-3-build-the-prompt-file) - 3 scripts and commands. Runs on: Slurm login pod.
* [D. Step 1: Deploy the GuideLLM client](#d-step-1-deploy-the-guidellm-client) - 4 scripts and commands. Runs on: laptop.
* [E. Step 2: Run the tests](#e-step-2-run-the-tests) - 4 scripts and commands. Runs on: laptop.

---

# A. Preparation 1: Suspend the `enroot-cleanup` health check

## A1. Log in to the Slurm login pod (laptop)

- **What it does:** Sets the SSH key and the login pod address, and opens a shell on the login pod.
- **Why we used it:** The jobs and the prompt file are handled from the login pod.
- **Section:** [Preparation 1: Suspend the `enroot-cleanup` health check](/06-Benchmarking/README.md#preparation-1-suspend-the-enroot-cleanup-health-check)

````bash
export KEY=~/.ssh/taher-soperator-demoday
export LOGIN_IP=$(kubectl -n soperator get svc soperator-login-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
ssh -i $KEY root@$LOGIN_IP
````

## A2. Suspend the health check (laptop)

- **What it does:** Shows the `enroot-cleanup` check, sets `suspend` to true, and shows it again.
- **Why we used it:** A running check would delay the `vLLM` restart and disturb a test.
- **Section:** [Preparation 1: Suspend the `enroot-cleanup` health check](/06-Benchmarking/README.md#preparation-1-suspend-the-enroot-cleanup-health-check)

````bash
kubectl -n soperator get activecheck enroot-cleanup
kubectl -n soperator patch activecheck enroot-cleanup --type=merge -p '{"spec":{"suspend":true}}'
kubectl -n soperator get activecheck enroot-cleanup
````

## A3. Cancel the waiting jobs (login pod)

- **What it does:** Lists the waiting jobs, cancels the `enroot-cleanup` jobs, and shows the queue.
- **Why we used it:** Suspending stops new runs only, so the jobs already in the queue must be removed.
- **Section:** [Preparation 1: Suspend the `enroot-cleanup` health check](/06-Benchmarking/README.md#preparation-1-suspend-the-enroot-cleanup-health-check)

````bash
squeue -t PD -o "%.8i %.14j %.9P %.6D %R"
scancel -n enroot-cleanup
squeue
````

---

# B. Preparation 2: More CPU and API processes for vLLM, and restart

## B1. Check the CPU of the running servers

- **What it does:** Shows how many CPUs each worker job holds.
- **Why we used it:** To prove that the jobs hold only 4 of the 16 CPUs before we change them.
- **Section:** [Preparation 2: Give `vLLM` more CPU and more API processes, and restart the servers](/06-Benchmarking/README.md#preparation-2-give-vllm-more-cpu-and-more-api-processes-and-restart-the-servers)

````bash
scontrol show node worker-0 | grep -E 'CPUAlloc|AllocTRES'
scontrol show node worker-1 | grep -E 'CPUAlloc|AllocTRES'
````

## B2. Edit the two `sbatch` files

- **What it does:** Adds 12 CPUs, 4 API processes and `--no-enable-prefix-caching` to both files.
- **Why we used it:** `vLLM` needs more CPU under load, and the prefix cache would make repeated questions look faster than they are.
- **Section:** [Preparation 2: Give `vLLM` more CPU and more API processes, and restart the servers](/06-Benchmarking/README.md#preparation-2-give-vllm-more-cpu-and-more-api-processes-and-restart-the-servers)

````bash
for f in /mnt/data/serve/serve-qwen-base.sbatch /mnt/data/serve/serve-qwen-tuned.sbatch; do
  sed -i 's/^#SBATCH --gres=gpu:1$/#SBATCH --gres=gpu:1\n#SBATCH --cpus-per-task=12/' $f
  sed -i 's/^srun --container-image=/srun --cpus-per-task=12 --container-image=/' $f
  sed -i 's/--generation-config vllm$/--generation-config vllm \\\n    --api-server-count 4 --no-enable-prefix-caching/' $f
done
````

## B3. Check the edited files

- **What it does:** Shows the three changed lines in each file.
- **Why we used it:** To confirm that each line appears once.
- **Section:** [Preparation 2: Give `vLLM` more CPU and more API processes, and restart the servers](/06-Benchmarking/README.md#preparation-2-give-vllm-more-cpu-and-more-api-processes-and-restart-the-servers)

````bash
grep -n -E 'cpus-per-task|api-server-count|prefix-caching' /mnt/data/serve/serve-qwen-base.sbatch /mnt/data/serve/serve-qwen-tuned.sbatch
````

## B4. Restart `Qwen-Base`

- **What it does:** Cancels the old base job, submits the edited file, and follows the log until all four API processes are ready.
- **Why we used it:** The new settings only take effect when the server restarts. We restart one server at a time, so one model always stays up.
- **Section:** [Preparation 2: Give `vLLM` more CPU and more API processes, and restart the servers](/06-Benchmarking/README.md#preparation-2-give-vllm-more-cpu-and-more-api-processes-and-restart-the-servers)

````bash
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
````

## B5. Check that `Qwen-Base` answers

- **What it does:** Asks the server for its model list with the key.
- **Why we used it:** To prove that the restarted server is up and accepts the key.
- **Section:** [Preparation 2: Give `vLLM` more CPU and more API processes, and restart the servers](/06-Benchmarking/README.md#preparation-2-give-vllm-more-cpu-and-more-api-processes-and-restart-the-servers)

````bash
KEYV=$(cat /mnt/data/secrets/vllm.key)
curl -s -H "Authorization: Bearer $KEYV" http://vllm-qwen-base:8000/v1/models | head -c 120; echo
````

## B6. Restart `Qwen-Tuned`

- **What it does:** Cancels the old tuned job, submits the edited file, and follows the log until all four API processes are ready.
- **Why we used it:** Same reason as the base model. Run it only when `Qwen-Base` is up.
- **Section:** [Preparation 2: Give `vLLM` more CPU and more API processes, and restart the servers](/06-Benchmarking/README.md#preparation-2-give-vllm-more-cpu-and-more-api-processes-and-restart-the-servers)

````bash
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
````

## B7. Check that `Qwen-Tuned` answers

- **What it does:** Asks the server for its model list with the key.
- **Why we used it:** To prove that the restarted server is up and accepts the key.
- **Section:** [Preparation 2: Give `vLLM` more CPU and more API processes, and restart the servers](/06-Benchmarking/README.md#preparation-2-give-vllm-more-cpu-and-more-api-processes-and-restart-the-servers)

````bash
KEYV=$(cat /mnt/data/secrets/vllm.key)
curl -s -H "Authorization: Bearer $KEYV" http://vllm-qwen-tuned:8000/v1/models | head -c 120; echo
````

---

# C. Preparation 3: Build the prompt file

## C1. Create the benchmark folders

- **What it does:** Creates `/mnt/data/benchmark/results` and opens the permissions of both folders.
- **Why we used it:** The client pod runs as a normal user and must write its result files there.
- **Section:** [Preparation 3: Build the prompt file](/06-Benchmarking/README.md#preparation-3-build-the-prompt-file)

````bash
# Create the benchmark folder and the results folder, and let the client pod write into them.
mkdir -p /mnt/data/benchmark/results && chmod 777 /mnt/data/benchmark /mnt/data/benchmark/results
````

## C2. Build `prompts.jsonl`

- **What it does:** Removes the correct SQL from every test row and mixes the rows with a fixed seed.
- **Why we used it:** The model must not receive the answer in its prompt, and both models must get the same questions in the same order.
- **Section:** [Preparation 3: Build the prompt file](/06-Benchmarking/README.md#preparation-3-build-the-prompt-file)

````bash
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
````

## C3. Check the file and the folders

- **What it does:** Lists the benchmark folder and counts the lines of the new file.
- **Why we used it:** To confirm that the file has 5,832 rows.
- **Section:** [Preparation 3: Build the prompt file](/06-Benchmarking/README.md#preparation-3-build-the-prompt-file)

````bash
ls -la /mnt/data/benchmark/                                 # Check the file is created
wc -l /mnt/data/benchmark/prompts.jsonl                     # Count the lines of the new file.
````

---

# D. Step 1: Deploy the GuideLLM client

## D1. Choose a system node

- **What it does:** Shows the CPU and memory already requested on each system node.
- **Why we used it:** The client needs free CPU, and the system nodes are small.
- **Section:** [Step 1. Deploy the GuideLLM client](/06-Benchmarking/README.md#step-1-deploy-the-guidellm-client)

````bash
# Show the requested CPU and memory of each system node.
kubectl describe nodes -l slurm.nebius.ai/nodeset=system | grep -E '^Name:|^  (cpu|memory) '
````

## D2. Save the chosen node

- **What it does:** Saves the name of the chosen node in `NODE`.
- **Why we used it:** The pod definition uses it to pin the client to that node.
- **Section:** [Step 1. Deploy the GuideLLM client](/06-Benchmarking/README.md#step-1-deploy-the-guidellm-client)

````bash
export NODE=<the name of the chosen system node>
````

## D3. Create the client pod

- **What it does:** Creates the `guidellm-client` pod on the chosen node, with the shared `/mnt/data` mounted.
- **Why we used it:** The client runs on a system node, so it never takes CPU from `vLLM`.
- **Section:** [Step 1. Deploy the GuideLLM client](/06-Benchmarking/README.md#step-1-deploy-the-guidellm-client)

````bash
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
````

## D4. Check the pod is running

- **What it does:** Shows the pod and the node it runs on.
- **Why we used it:** To confirm that the client is ready before the tests.
- **Section:** [Step 1. Deploy the GuideLLM client](/06-Benchmarking/README.md#step-1-deploy-the-guidellm-client)

````bash
kubectl -n soperator get pod guidellm-client -o wide
````

---

# E. Step 2: Run the tests

## E1. Test 1: the original model, scenario A

- **What it does:** Runs a `GuideLLM` sweep against `vllm-qwen-base` with natural answers.
- **Why we used it:** This shows what a user of the original model feels.
- **Section:** [Test 1: the original model, scenario A (natural answers)](/06-Benchmarking/README.md#test-1-the-original-model-scenario-a-natural-answers)

````bash
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
````

## E2. Test 2: the tuned model, scenario A

- **What it does:** Runs the same sweep against `vllm-qwen-tuned`.
- **Why we used it:** To compare the tuned model with the original on the same questions.
- **Section:** [Test 2: the tuned model, scenario A (natural answers)](/06-Benchmarking/README.md#test-2-the-tuned-model-scenario-a-natural-answers)

````bash
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
````

## E3. Test 3: the original model, scenario B

- **What it does:** Runs the sweep against `vllm-qwen-base` with 128 forced tokens.
- **Why we used it:** Equal work for both models, so any difference comes from the engine.
- **Section:** [Test 3: the original model, scenario B (equal answers)](/06-Benchmarking/README.md#test-3-the-original-model-scenario-b-equal-answers)

````bash
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
````

## E4. Test 4: the tuned model, scenario B

- **What it does:** Runs the sweep against `vllm-qwen-tuned` with 128 forced tokens.
- **Why we used it:** The tuned model would stop after a short SQL line, so the forced length makes the work equal.
- **Section:** [Test 4: the tuned model, scenario B (equal answers)](/06-Benchmarking/README.md#test-4-the-tuned-model-scenario-b-equal-answers)

````bash
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
````

---
