# 01-Provided Service Account Lacks Required Permissions

> Terraform could not use the provided `soperator-taher-shaker-tfstate-sa` service account to read or write its state in the provided `csa-soperator-tfstate-taher-shaker-e00hq8rd` bucket. Every request returned `403 Forbidden`, and `terraform init` stopped. The other provided service account, `mlflow-sa`, is in the `editors` group and can use the same bucket. Using the other provided services account - `mlflow-sa` - fixed the issue. 


---

# Issue Summary

- Nebius provided two service accounts (`soperator-taher-shaker-tfstate-sa` and `mlflow-sa`) and one object storage bucket (`csa-soperator-tfstate-taher-shaker-e00hq8rd`).
- My read is, the `Soperator` Terraform code should use these resources, and should not create new ones.
- From the name, I assumed `soperator-taher-shaker-tfstate-sa` is the account for the state bucket.
- That account failed with `403 Forbidden` on the bucket.
- `mlflow-sa` worked on the same bucket, so I used it.

---

# Questions to Nebius team

1. Is using `mlflow-sa` for the Terraform state backend the expected approach?
2. If not, should I ask the Nebius team to update the permissions of `soperator-taher-shaker-tfstate-sa`? My user cannot change group membership, so I cannot fix this myself.

---

# Issue Discription 

When I first opened the tenant (`csa-hiring-sandbox`) and the project (`csa-demoday-soperator-taher-shaker`), I found one bucket and two service accounts:

| Item | Name | Group |
|---|---|---|
| Bucket | `csa-soperator-tfstate-taher-shaker-e00hq8rd` | n/a |
| Service account | `mlflow-sa` | `editors` |
| Service account | `soperator-taher-shaker-tfstate-sa` | `soperator-taher-shaker-tfstate-writers` |


Looking at the `Soperator` Terraform code, it keeps its state (`tfstate`) in a bucket. The `.envrc` script prepares this: it creates a service account called `slurm-terraform-sa`, adds it to the `editors` group, and creates a bucket named `tfstate-slurm-k8s-xxxx`. 

At first glance, I understood that I need to edit `.envrc` to use the provided service account and the provided bucket. As a test, I sourced `.envrc` without any change. It created the service account, but it could not add it to the `editors` group. The error was `Error: rpc error: code = PermissionDenied desc = No permission`. For the full output, see [01-error1](/07-Finding-&-Troubleshootings/01-Provided-SA-Lacks-Required-Permissions/01-error1.txt).

Based on the names of the service accounts, I assumed that the `soperator-taher-shaker-tfstate-sa` is the service account to use. I edited `.envrc` to use this service account and the provided bucket, and I sourced it again. It worked, see [02-output1](/07-Finding-&-Troubleshootings/01-Provided-SA-Lacks-Required-Permissions/02-output1.txt). However, when I ran `terraform init`, I got the error `Error refreshing state: Unable to access object "slurm-k8s.tfstate"` (HTTP 403).

![image1](/07-Finding-&-Troubleshootings/01-Provided-SA-Lacks-Required-Permissions/Images/image1.png)

This error clearly says that the `soperator-taher-shaker-tfstate-sa` service account do not have the required read permisions on the provided bucket - eventhough the error says it is unable to access the object, the main reason is it is `Forbiden`

> **Task**

- Need to check the permisions of the provided `soperator-taher-shaker-tfstate-sa` service account
- Need to check the permissions of the provided `mlflow-sa` services account
- Need to check if i can use my own account
- Need to check if i should create a new service account and use it
- Need to check if the provided bucket have no issues related to permissions

[**Finally - A Workaround or Fix**] - have a services account with the correct permission to perform the required task.

---

# Troubleshooting steps

## Step 1: Test the bucket directly with the AWS CLI

First, I wanted to test the access of this service account without the Terraform script, to remove any issue caused by the script. In my terminal, `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` were still set to the key that the `.envrc` script created for the service account. I used the AWS CLI to list the objects in the `csa-soperator-tfstate-taher-shaker-e00hq8rd` bucket.

```bash
echo $AWS_ACCESS_KEY_ID
NAKI************  # <<----- This is the key created when I sourced the .envrc script
```

```bash
aws s3 ls "s3://csa-soperator-tfstate-taher-shaker-e00hq8rd/" --endpoint-url https://storage.eu-north1.nebius.cloud
```

Result: access denied. The failure is not caused by Terraform.

![image2](/07-Finding-&-Troubleshootings/01-Provided-SA-Lacks-Required-Permissions/Images/image2.png)

---

## Step 2: Test the bucket with a newly created key

Next, I wanted to check whether the key created by the `.envrc` script was the problem. I created a new access key for the `soperator-taher-shaker-tfstate-sa` service account and configured a new AWS CLI profile with it.

```bash
aws configure --profile test-sa-key
aws configure list-profiles
```

![image3](/07-Finding-&-Troubleshootings/01-Provided-SA-Lacks-Required-Permissions/Images/image3.png)

I then used the AWS CLI with the new profile to list the objects in the `csa-soperator-tfstate-taher-shaker-e00hq8rd` bucket.

```bash
aws s3 ls "s3://csa-soperator-tfstate-taher-shaker-e00hq8rd/" --profile test-sa-key --endpoint-url https://storage.eu-north1.nebius.cloud
```

Result: the same error. A new key does not change the result, so the key is not the problem. The account is.

![image4](/07-Finding-&-Troubleshootings/01-Provided-SA-Lacks-Required-Permissions/Images/image4.png)

---

## Step 3: Create another service account and add it to the `editors` group

I wanted to create my own service account with the `editors` rights. after creating the new service account, i tried to add it to the `editors` group in the console, but it failed. My user does not have permission to change groups.

![image5](/07-Finding-&-Troubleshootings/01-Provided-SA-Lacks-Required-Permissions/Images/image5.png)

---

## Step 4: Check that my own user can reach the bucket

I checked that my own user can upload files to the bucket and see the objects in it. It worked fine, so the bucket itself is healthy and reachable.

![image6](/07-Finding-&-Troubleshootings/01-Provided-SA-Lacks-Required-Permissions/Images/image6.png)

---

## Step 5: Try an S3 key for my own user

Because my user can use the bucket, I tried to create an S3 access key for my user, to use it with the AWS CLI and Terraform. The command was refused with the error `Unsupported account type useraccount`. This means S3 keys can only be created for service accounts.

```bash
export NEBIUS_USER_ID=$(nebius iam whoami --format json | jq -r '.. | strings | select(startswith("useraccount-"))' | head -1)
nebius iam v2 access-key create --parent-id "$NEBIUS_PROJECT_ID" --name "demoday-user-ak-test" --account-user-account-id "$NEBIUS_USER_ID" --expires-at "$(date -v +1d '+%Y-%m-%dT%H:%M:%SZ')" --format json
```

Result: Unlinke AWS, in Nebius you can not use a normal user to access S3 buckets using the CLI.

![image7](/07-Finding-&-Troubleshootings/01-Provided-SA-Lacks-Required-Permissions/Images/image7.png)

---

## Step 6: Use the `mlflow-sa` service account to compare permissions

`mlflow-sa` is a member of the `editors` group. I created an access key for it in the console and tested the same bucket. I could list the objects, upload a file, read it back, and delete it.

```bash
aws configure --profile mlflow-s3
aws s3 ls "s3://csa-soperator-tfstate-taher-shaker-e00hq8rd/" --profile mlflow-s3 --endpoint-url https://storage.eu-north1.nebius.cloud
echo "test" > /tmp/test.txt
aws s3 cp /tmp/test.txt "s3://csa-soperator-tfstate-taher-shaker-e00hq8rd/test.txt" --profile mlflow-s3 --endpoint-url https://storage.eu-north1.nebius.cloud
aws s3 ls "s3://csa-soperator-tfstate-taher-shaker-e00hq8rd/" --profile mlflow-s3 --endpoint-url https://storage.eu-north1.nebius.cloud
aws s3 rm "s3://csa-soperator-tfstate-taher-shaker-e00hq8rd/test.txt" --profile mlflow-s3 --endpoint-url https://storage.eu-north1.nebius.cloud
```

Result: all commands worked. The bucket is fine, and `mlflow-sa` has the rights that Terraform needs.

![image8](/07-Finding-&-Troubleshootings/01-Provided-SA-Lacks-Required-Permissions/Images/image8.png)

---

# Conclusion

The bucket is fine, and my access to it is fine. The provided `soperator-taher-shaker-tfstate-sa` service account has no required rights, even though it is a member of the `tfstate-writers` group. The `mlflow-sa` service account have the required permisions and can be used with the Terraform script.

---

# Workaround

I used the key of the `mlflow-sa` service account for the Terraform S3 backend, instead of the key of `soperator-taher-shaker-tfstate-sa`.

---
