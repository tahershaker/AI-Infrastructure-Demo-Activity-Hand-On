# 04 - Fine-Tuning: Scripts and Commands

> Every script and main command used in the fine-tuning activity, in the order they were run. Each entry gives the name of the step, what it does, why we used it, a link to the section of the [Fine-Tuning README](/04-Fine-Tune/README.md) that explains it, and the code itself.

---

# Summary

This is a summary of the file, with a link to each group of scripts.

* [A. Download the dataset](#a-download-the-dataset) - 3 scripts and commands. Runs on: laptop.
* [B. Prepare the Python environment](#b-prepare-the-python-environment) - 3 scripts and commands. Runs on: laptop.
* [C. Phase 1: Data validation](#c-phase-1-data-validation) - 3 scripts and commands. Runs on: laptop.
* [D. Phase 2: Data checking for the Axolotl settings](#d-phase-2-data-checking-for-the-axolotl-settings) - 2 scripts and commands. Runs on: laptop.
* [E. Phase 3: Data preparation](#e-phase-3-data-preparation) - 4 scripts and commands. Runs on: laptop.
* [F. Upload the data](#f-upload-the-data) - 8 scripts and commands. Runs on: laptop and Slurm login pod.
* [G. Check flash attention](#g-check-flash-attention) - 2 scripts and commands. Runs on: Slurm login pod.
* [H. Create the Axolotl configuration](#h-create-the-axolotl-configuration) - 2 scripts and commands. Runs on: Slurm login pod.
* [I. Smoke test on one node](#i-smoke-test-on-one-node) - 4 scripts and commands. Runs on: Slurm login pod.
* [J. Test on two nodes](#j-test-on-two-nodes) - Run the two-node test. Runs on: Slurm login pod.
* [K. Run the fine-tuning](#k-run-the-fine-tuning) - 4 scripts and commands. Runs on: Slurm login pod.
* [L. Test the tuned model](#l-test-the-tuned-model) - 3 scripts and commands. Runs on: Slurm login pod.

---

# A. Download the dataset

*Runs on: laptop.*

## A1. Create the dataset folder

- **What it does:** Creates a folder for the dataset and saves its path in `DATA_DIR`.
- **Why we used it:** All later scripts read their files from one known folder.
- **Section:** [Downloading the dataset](/04-Fine-Tune/README.md#downloading-the-dataset)

````bash
mkdir -p ~/Downloads/dataset_synthetic_text_to_sql
cd ~/Downloads/dataset_synthetic_text_to_sql
export DATA_DIR=~/Downloads/dataset_synthetic_text_to_sql
````

## A2. Install the Hugging Face CLI

- **What it does:** Installs the `hf` command and prints its version.
- **Why we used it:** We need it to download the dataset from the Hub.
- **Section:** [Step 1: Install the Hugging Face CLI](/04-Fine-Tune/README.md#step-1-install-the-hugging-face-cli)

````bash
brew install hf
hf version
````

## A3. Download the dataset

- **What it does:** Downloads the whole dataset repository, pinned to one commit.
- **Why we used it:** A pinned commit means the data cannot change between runs.
- **Section:** [Step 2: Download the dataset to the laptop](/04-Fine-Tune/README.md#step-2-download-the-dataset-to-the-laptop)

````bash
hf download gretelai/synthetic_text_to_sql \
  --repo-type dataset \
  --revision 740ab236e64503fba51be1101df7a1be83bf455d \
  --local-dir .
ls -lh
```
````

---

# B. Prepare the Python environment

## B1. Create the virtual environment and install the packages

- **What it does:** Creates a private Python environment with `pandas`, `pyarrow`, `transformers` and `jinja2`.
- **Why we used it:** The checks need these packages, and nothing is installed into the system Python.
- **Section:** [Preparing the Python virtual environment](/04-Fine-Tune/README.md#preparing-the-python-virtual-environment)

````bash
python3 -m venv ~/nebius-demoday/.venv-data
source ~/nebius-demoday/.venv-data/bin/activate
pip install pandas pyarrow transformers jinja2
````

## B2. Reopen the environment in a new terminal

- **What it does:** Activates the environment again and moves to the dataset folder.
- **Why we used it:** The environment lasts only as long as the terminal window.
- **Section:** [Preparing the Python virtual environment](/04-Fine-Tune/README.md#preparing-the-python-virtual-environment)

````bash
source ~/nebius-demoday/.venv-data/bin/activate
export DATA_DIR=~/Downloads/dataset_synthetic_text_to_sql
cd "$DATA_DIR"
````

---

# C. Phase 1: Data validation

## C1. Validation 1: Missing and blank values

- **What it does:** Counts empty and blank cells in the three training columns.
- **Why we used it:** An empty question or answer teaches the model nothing, or something wrong.
- **Section:** [Validation 1: Missing and blank values](/04-Fine-Tune/README.md#validation-1-missing-and-blank-values)

````bash
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
````

## C2. Validation 2: Duplicates

- **What it does:** Counts examples that appear more than once in the training data.
- **Why we used it:** Repeated examples are memorized and do not teach the general skill.
- **Section:** [Validation 2: Duplicates](/04-Fine-Tune/README.md#validation-2-duplicates)

````bash
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
````

## C3. Validation 3: Overlap between train and test

- **What it does:** Counts test examples that also appear in the training data, in three ways.
- **Why we used it:** A test example the model has already seen makes the final test unfair.
- **Section:** [Validation 3: Overlap between the train data and the test data](/04-Fine-Tune/README.md#validation-3-overlap-between-the-train-data-and-the-test-data)

````bash
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
````

---

# D. Phase 2: Data checking for the Axolotl settings

## D1. Check 1: The structure

- **What it does:** Prints the row counts, the columns and one full example.
- **Why we used it:** To know which column is the question, the tables and the answer, for the `datasets` block.
- **Section:** [Check 1: The structure](/04-Fine-Tune/README.md#check-1-the-structure)

````bash
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
````

## D2. Check 2: The length of the texts

- **What it does:** Measures the longest, the shortest and the percentile lengths, in characters.
- **Why we used it:** To get a first estimate for `sequence_len`.
- **Section:** [Check 2: The length of the texts](/04-Fine-Tune/README.md#check-2-the-length-of-the-texts)

````bash
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
````

---

# E. Phase 3: Data preparation

## E1. 3a. Clean the test data

- **What it does:** Removes the 19 test rows that also appear in the training data, and saves `test_clean.parquet`.
- **Why we used it:** So the final comparison is fair.
- **Section:** [3a. Handle the issues found in the validation](/04-Fine-Tune/README.md#3a-handle-the-issues-found-in-the-validation)

````bash
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
````

## E2. 3b. Convert the train data

- **What it does:** Turns each training row into a conversation (system, user, assistant) and writes `train.jsonl`.
- **Why we used it:** The `chat_template` dataset type needs the data as a list of messages.
- **Section:** [3b. Convert the train data](/04-Fine-Tune/README.md#3b-convert-the-train-data)

````bash
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
````

## E3. 3c. Convert the test data

- **What it does:** Applies the same conversion to the clean test data and writes `test.jsonl`.
- **Why we used it:** Both models must get the test questions in the exact format used in training.
- **Section:** [3c. Convert the test data](/04-Fine-Tune/README.md#3c-convert-the-test-data)

````bash
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
````

## E4. 3d. Check the converted training data

- **What it does:** Counts the real tokens, and checks the chat template, the start and the end marker.
- **Why we used it:** To set `sequence_len` and `sample_packing`, and to make sure no example is dropped without warning.
- **Section:** [3d. Check the converted training data for the Axolotl settings](/04-Fine-Tune/README.md#3d-check-the-converted-training-data-for-the-axolotl-settings)

````bash
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
````

---

# F. Upload the data

## F1. Set the variables (laptop)

- **What it does:** Saves the dataset path, the SSH key and the login pod address.
- **Why we used it:** The upload commands use all three.
- **Section:** [Uploading the data](/04-Fine-Tune/README.md#uploading-the-data)

````bash
export DATA_DIR=~/Downloads/dataset_synthetic_text_to_sql
export KEY=~/.ssh/taher-soperator-demoday
export LOGIN_IP=$(kubectl -n soperator get svc soperator-login-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
````

## F2. Record the checksums (laptop)

- **What it does:** Prints a fingerprint for each data file.
- **Why we used it:** To compare with the cluster copy after the upload.
- **Section:** [Step 1: Check the files and record their checksums](/04-Fine-Tune/README.md#step-1-check-the-files-and-record-their-checksums)

````bash
cd "$DATA_DIR"
ls -lh
shasum -a 256 *.parquet
shasum -a 256 ready/train.jsonl ready/test.jsonl
````

## F3. Log in to the login pod (laptop)

- **What it does:** Opens a shell on the Slurm login pod.
- **Why we used it:** The folders on the cluster are created from there.
- **Section:** [Step 2: Prepare the folders on the cluster](/04-Fine-Tune/README.md#step-2-prepare-the-folders-on-the-cluster)

````bash
ssh -i "$KEY" root@"$LOGIN_IP"
````

## F4. Check the disk and create the folders (login pod)

- **What it does:** Confirms `/mnt/data` is the large shared disk, and creates the folder layout.
- **Why we used it:** A folder on the wrong disk would fill the small boot disk of the login pod.
- **Section:** [Step 2: Prepare the folders on the cluster](/04-Fine-Tune/README.md#step-2-prepare-the-folders-on-the-cluster)

````bash
df -h /mnt/data
ls -ld /mnt/data
mkdir -p /mnt/data/data/raw /mnt/data/hf-cache /mnt/data/outputs /mnt/data/configs /mnt/data/logs /mnt/data/prepared
ls -la /mnt/data
````

## F5. Upload the files (laptop)

- **What it does:** Copies the Parquet files, the dataset card, `train.jsonl` and `test.jsonl` to `/mnt/data`.
- **Why we used it:** The cluster must hold the data on the shared filesystem.
- **Section:** [Step 3: Upload the files](/04-Fine-Tune/README.md#step-3-upload-the-files)

````bash
scp -i "$KEY" *.parquet README.md root@"$LOGIN_IP":/mnt/data/data/raw/
scp -i "$KEY" ready/train.jsonl ready/test.jsonl root@"$LOGIN_IP":/mnt/data/data/
````

## F6. Verify the upload (login pod)

- **What it does:** Calculates the checksums again on the cluster.
- **Why we used it:** Matching checksums prove that the copy is identical.
- **Section:** [Step 4: Verify the upload](/04-Fine-Tune/README.md#step-4-verify-the-upload)

````bash
cd /mnt/data/data/raw
ls -lh
sha256sum *.parquet

cd ..
ls -lh
sha256sum train.jsonl test.jsonl
````

## F7. Check that both workers see the files (login pod)

- **What it does:** Runs a small job on both workers that prints the checksums.
- **Why we used it:** The training runs on the workers, so both must see the same files.
- **Section:** [Step 5: Check that the worker nodes see the same files](/04-Fine-Tune/README.md#step-5-check-that-the-worker-nodes-see-the-same-files)

````bash
srun -l -N2 --ntasks-per-node=1 bash -c 'hostname && sha256sum /mnt/data/data/raw/*.parquet /mnt/data/data/train.jsonl /mnt/data/data/test.jsonl'
````

## F8. Check that the workers can write to the shared disk (login pod)

- **What it does:** Writes a file on `worker-0`, reads it on `worker-1`, and removes it.
- **Why we used it:** Both workers write the cache and the checkpoints during training.
- **Section:** [Step 5: Check that the worker nodes see the same files](/04-Fine-Tune/README.md#step-5-check-that-the-worker-nodes-see-the-same-files)

````bash
srun -N1 -w worker-0 bash -c 'echo "written by worker-0" > /mnt/data/logs/node_test.txt'
srun -N1 -w worker-1 cat /mnt/data/logs/node_test.txt
rm /mnt/data/logs/node_test.txt
````

---

# G. Check flash attention

## G1. Create `flash_check.py`

- **What it does:** Writes a script that checks the `flash_attn` package and the PyTorch flash kernel.
- **Why we used it:** To find out whether the image supports flash attention.
- **Section:** [Checking flash attention](/04-Fine-Tune/README.md#checking-flash-attention)

````bash
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
````

## G2. Run `flash_check.py` in the container

-**What it does:** Runs the script on one worker, inside the Axolotl image.
- **Why we used it:** The result sets `attn_implementation` in the Axolotl file.
- **Section:** [Checking flash attention](/04-Fine-Tune/README.md#checking-flash-attention)

````bash
srun --nodes=1 --gres=gpu:1 --cpus-per-task=16 \
  --container-image=axolotlai/axolotl:main-20261013-py3.12-cu130-2.13.0 \
  --container-mounts=/mnt/data:/mnt/data \
  python3 /mnt/data/logs/flash_check.py
````

---

# H. Create the Axolotl configuration

## H1. Open the config file

- **What it does:** Opens `lora-sql-qwen7b.yaml` in `vi` in `/mnt/data/configs/`, then prints it.
- **Why we used it:** The file must exist on the shared disk before the training starts.
- **Section:** [The Axolotl configuration](/04-Fine-Tune/README.md#the-axolotl-configuration)

````bash
cd /mnt/data/configs
vi lora-sql-qwen7b.yaml
cat lora-sql-qwen7b.yaml
````

## H2. The Axolotl YAML file

- **What it does:** Holds the whole run: model, LoRA settings, data, batch and saving.
- **Why we used it:** One file describes the run, so it is easy to repeat and review.
- **Section:** [The Axolotl configuration](/04-Fine-Tune/README.md#the-axolotl-configuration)

````yaml
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
````

---

# I. Smoke test on one node

## I1. Start the smoke test

- **What it does:** Trains 20 steps on one worker and samples the GPU every 2 seconds.
- **Why we used it:** To check the config, the memory and the GPU before the real run.
- **Section:** [Running the smoke test](/04-Fine-Tune/README.md#running-the-smoke-test)

````bash
srun --nodes=1 --gres=gpu:1 --cpus-per-task=16 --time=00:40:00 \
  --container-image=axolotlai/axolotl:main-20261013-py3.12-cu130-2.13.0 \
  --container-mounts=/mnt/data:/mnt/data \
  bash -c 'export HF_HOME=/mnt/data/hf-cache
nvidia-smi --query-gpu=timestamp,utilization.gpu,memory.used --format=csv -l 2 > /mnt/data/logs/gpu_smoke.csv &
SMI=$!
axolotl train /mnt/data/configs/lora-sql-qwen7b.yaml --max-steps 20 --output-dir /mnt/data/outputs/smoke2
kill $SMI' \
  2>&1 | tee /mnt/data/logs/smoke2.log
````

## I2. Read the key lines of the log

- **What it does:** Shows the `sdpa_varlen`, loss, `train_runtime` and save lines.
- **Why we used it:** To confirm that `sdpa` works with packing and that the loss goes down.
- **Section:** [Running the smoke test](/04-Fine-Tune/README.md#running-the-smoke-test)

````bash
grep -E "sdpa_varlen|'loss'|'eval_loss'|train_runtime|successfully saved" /mnt/data/logs/smoke2.log
````

## I3. Summarize the GPU samples

- **What it does:** Calculates the average GPU utilization of the busy samples.
- **Why we used it:** To measure how busy the GPU is.
- **Section:** [Running the smoke test](/04-Fine-Tune/README.md#running-the-smoke-test)

````bash
awk -F', ' 'NR>1 && $2+0>0 {n++; s+=$2+0; if ($2+0<50) low++} END {if (n) printf "Samples with the GPU busy: %d\nAverage utilization: %.0f%%\nSamples below 50%%: %d\n", n, s/n, low}' /mnt/data/logs/gpu_smoke.csv
````

## I4. Look at the last 40 GPU samples

- **What it does:** Prints the last samples with time, utilization and memory.
- **Why we used it:** To see the utilization and the memory while the model trains.
- **Section:** [Running the smoke test](/04-Fine-Tune/README.md#running-the-smoke-test)

````bash
tail -n 40 /mnt/data/logs/gpu_smoke.csv
````

---

# J. Test on two nodes

## J1. Run the two-node test

- **What it does:** Trains 20 steps on both workers as one job, with `NCCL_DEBUG=INFO`.
- **Why we used it:** To prove that both GPUs train together over Ethernet, and to get the real step time.
- **Section:** [Testing on two nodes](/04-Fine-Tune/README.md#testing-on-two-nodes)

````bash
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
````

---

# K. Run the fine-tuning

## K1. Check that the cluster is free

- **What it does:** Lists the running Slurm jobs.
- **Why we used it:** An old job would hold the GPU.
- **Section:** [Running the fine-tuning](/04-Fine-Tune/README.md#running-the-fine-tuning)

````bash
squeue
````

## K2. Start the training

- **What it does:** Runs the real fine-tune on both workers with the final config.
- **Why we used it:** This is the fine-tuning job itself.
- **Section:** [Running the fine-tuning](/04-Fine-Tune/README.md#running-the-fine-tuning)

````bash
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
````

## K3. Check the output folder

- **What it does:** Lists the adapter, the tokenizer files and the checkpoints.
- **Why we used it:** To confirm that the adapter was saved.
- **Section:** [Running the fine-tuning](/04-Fine-Tune/README.md#running-the-fine-tuning)

````bash
ls -lh /mnt/data/outputs/qwen25-7b-sql-lora
````

## K4. Read the key lines of the log

- **What it does:** Shows the last loss lines, the validation loss and the run time.
- **Why we used it:** To record the result of the training.
- **Section:** [Running the fine-tuning](/04-Fine-Tune/README.md#running-the-fine-tuning)

````bash
grep -E "'loss'|'eval_loss'|train_runtime|successfully saved" /mnt/data/logs/train.log | tail -n 20
````

---

# L. Test the tuned model

## L1. Create `compare.py`

- **What it does:** Writes a script that sends the same 20 questions to the original and the tuned model.
- **Why we used it:** To show that the adapter changes what the model does.
- **Section:** [Testing the tuned model](/04-Fine-Tune/README.md#testing-the-tuned-model)

````bash
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
````

## L2. Run `compare.py` on one worker

- **What it does:** Runs the comparison and saves the output to `compare.log`.
- **Why we used it:** To get the answers of both models and the summary.
- **Section:** [Testing the tuned model](/04-Fine-Tune/README.md#testing-the-tuned-model)

````bash
srun --nodes=1 --gres=gpu:1 --cpus-per-task=16 --time=00:30:00 \
  --container-image=axolotlai/axolotl:main-20261013-py3.12-cu130-2.13.0 \
  --container-mounts=/mnt/data:/mnt/data \
  bash -c 'export HF_HOME=/mnt/data/hf-cache && python3 /mnt/data/logs/compare.py' \
  2>&1 | tee /mnt/data/logs/compare.log
````

## L3. Create `compare-3ep.py`

- **What it does:** Same as `compare.py`, but it loads the 3-epoch adapter `qwen25-7b-sql-lora-3ep`.
- **Why we used it:** To compare the original model with the adapter trained for 3 epochs.
- **Section:** [Testing the tuned model](/04-Fine-Tune/README.md#testing-the-tuned-model)

````bash
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
````

---
