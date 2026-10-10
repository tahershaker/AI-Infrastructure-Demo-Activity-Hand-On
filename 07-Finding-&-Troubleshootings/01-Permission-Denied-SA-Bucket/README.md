01-Permission-Deined-For-Provided-tfstate-SA-To-Access-Existing-Bucket

> Using the provided `soperator-taher-shaker-tfstate-sa` service account failed when trying to read or write files in the provided `csa-soperator-tfstate-taher-shaker-e00hq8rd` bucket. This stopped `terraform init` and blocked the Soperator Terraform script. I proved the cause is a missing permission, not a wrong key or a wrong tool, and I used `mlflow-sa` as a workaround.

---

# Issue Discription 

When I log in to the provided tenant, I can see an existing bucket `csa-soperator-tfstate-taher-shaker-e00hq8rd` and two existing service accounts: `mlflow-sa` - assigned to `editor` group - and `soperator-taher-shaker-tfstate-sa` - assigned to s`operator-taher-shaker-tfstate-writers` group.

Going through the Soperator Terraform code and the `.envrc` script, I understood that Terraform saves its state (`tfstate`) in a bucket to keep it safe. The `.envrc` script creates a service account called `slurm-terraform-sa`, adds it to the `editors` group, and creates a bucket whose name starts with `tfstate-slurm-k8s-xxxx`.

At first glance, I understood that I need to edit `.envrc` to use the provided service account and the provided bucket. As a test, I sourced `.envrc` without any change. It created the service account, but it could not add it to the `editors` group. The error was `Error: rpc error: code = PermissionDenied desc = No permission`. For the full output, see [01-error1](/07-Finding-&-Troubleshootings/01-Permission-Denied-SA-Bucket/01-error1.txt).

Because of the names, I guessed that `soperator-taher-shaker-tfstate-sa` is the account to use. I edited `.envrc` to use this service account and the provided bucket, and I sourced it again. It worked, see [02-output1](/07-Finding-&-Troubleshootings/01-Permission-Denied-SA-Bucket/02-output1.txt). However, when I ran `terraform init`, I got the error `Error refreshing state: Unable to access object "slurm-k8s.tfstate"` (HTTP 403).

![image1](/07-Finding-&-Troubleshootings/01-Permission-Denied-SA-Bucket/Images/image1.png)

A missing state file is normal on a first run, because Terraform only checks whether the file exists. A 403 means something else: the account is not allowed to access the bucket at all. So the permission given to `soperator-taher-shaker-tfstate-sa` was not enough.

---

# Troubleshooting steps

I ran several tests, one at a time, so that each one removes one possible cause.

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

![image2](/07-Finding-&-Troubleshootings/01-Permission-Denied-SA-Bucket/Images/image2.png)

## Step 2: Test the bucket with a newly created key

Next, I wanted to check whether the key created by the `.envrc` script was the problem. I created a new access key for the `soperator-taher-shaker-tfstate-sa` service account and configured a new AWS CLI profile with it.

```bash
aws configure --profile test-sa-key
aws configure list-profiles
```

I then used the AWS CLI with the new profile to list the objects in the `csa-soperator-tfstate-taher-shaker-e00hq8rd` bucket.

```bash
aws s3 ls "s3://csa-soperator-tfstate-taher-shaker-e00hq8rd/" --profile test-sa-key --endpoint-url https://storage.eu-north1.nebius.cloud
```

Result: the same error. A new key does not change the result, so the key is not the problem. The account is.

![image4](/07-Finding-&-Troubleshootings/01-Permission-Denied-SA-Bucket/Images/image4.png)

## Step 3: Create another service account and add it to the `editors` group

I wanted to create my own service account with the `editors` rights. I tried to add it to the `editors` group in the console, but it failed. My user does not have permission to change groups.

![image5](/07-Finding-&-Troubleshootings/01-Permission-Denied-SA-Bucket/Images/image5.png)

## Step 4: Check that my own user can reach the bucket

I checked that my own user can upload files to the bucket and see the objects in it. It worked fine, so the bucket itself is healthy and reachable.

![image6](/07-Finding-&-Troubleshootings/01-Permission-Denied-SA-Bucket/Images/image6.png)

## Step 5: Try an S3 key for my own user

Because my user can use the bucket, I tried to create an S3 access key for my user, to use it with the AWS CLI and Terraform. The command was refused with the error `Unsupported account type useraccount`. This means S3 keys can only be created for service accounts.

```bash
export NEBIUS_USER_ID=$(nebius iam whoami --format json | jq -r '.. | strings | select(startswith("useraccount-"))' | head -1)
nebius iam v2 access-key create --parent-id "$NEBIUS_PROJECT_ID" --name "demoday-user-ak-test" --account-user-account-id "$NEBIUS_USER_ID" --expires-at "$(date -v +1d '+%Y-%m-%dT%H:%M:%SZ')" --format json
```

![image7](/07-Finding-&-Troubleshootings/01-Permission-Denied-SA-Bucket/Images/image7.png)

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

![image8](/07-Finding-&-Troubleshootings/01-Permission-Denied-SA-Bucket/Images/image8.png)

---

# Conclusion

The bucket is fine, and my access to it is fine. The provided service account has no usable rights on the provided bucket, even though it is a member of the `tfstate-writers` group.

I could not find the reason, because group roles and bucket access settings are hidden from my user. My hypothesis is that the group has no write role on this bucket, or that the role is attached to a different resource. A tenant admin needs to confirm this. I did not raise it with the Nebius team, because it was the weekend.

---

# Workaround

I used the key of the `mlflow-sa` service account for the Terraform S3 backend, instead of the key of `soperator-taher-shaker-tfstate-sa`.

---
