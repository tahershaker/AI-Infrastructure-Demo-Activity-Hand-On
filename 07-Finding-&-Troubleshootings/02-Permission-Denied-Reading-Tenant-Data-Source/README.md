# 02-Permission-Denied-Reading-Tenant-Data-Source

> `terraform plan` and `terraform apply` failed with `PermissionDenied` while reading the tenant resource. The Soperator recipe declares a lookup of the tenant, but nothing in the code uses its result. My sandbox user cannot read the tenant, so I commented out the unused lookup in my installation copy of `variables.tf`.

---

# Issue Description

After `terraform init` succeeded (see [01-Permission-Denied-For-Provided-tfstate-SA-To-Access-Existing-Bucket](/07-Finding-&-Troubleshootings/01-Permission-Denied-SA-Bucket/README.md)), I ran `terraform plan`. The plan was built, but Terraform stopped with this error:

```
Error: datasource reading by ID failed

  with data.nebius_iam_v1_tenant.this,
  on variables.tf line 50, in data "nebius_iam_v1_tenant" "this":
  50:   id = var.iam_tenant_id

datasource reading by ID failed: service get: rpc error: code = PermissionDenied desc = No permission
```

![image1](/07-Finding-&-Troubleshootings/02-Permission-Denied-Reading-Tenant-Data-Source/Images/image1.png)

This means Terraform asked Nebius to read the tenant `csa-hiring-sandbox`, and my user is not allowed to do that. It is the same kind of limit as the earlier refusal when I tried to list groups in the tenant. My user can work inside the project, but not on the tenant itself.

---

# Troubleshooting steps

## Step 1: Find out what the lookup is

The error names the file and the line. In my installation folder, `variables.tf` has this block:

```hcl
data "nebius_iam_v1_tenant" "this" {
  id = var.iam_tenant_id
}
```

A `data` block creates nothing. It only asks Nebius for information about something that already exists, so that Terraform can use the answer in other places. In plain words, it says: "Ask Nebius for the tenant with this ID, and keep the answer under the name `this`."

Terraform reads every `data` block it finds before it plans, even when nothing uses the answer. So this lookup ran, my user is not allowed to read the tenant, and the whole run stopped.

The next step is to check whether anything else uses the answer from this block.

## Step 2: Check whether anything uses the result

I searched the whole Soperator release (v4.1.13-2) for any use of this lookup:

```bash
grep -rn "nebius_iam_v1_tenant" .
grep -rn "tenant\.this" .
```

![image2](/07-Finding-&-Troubleshootings/02-Permission-Denied-Reading-Tenant-Data-Source/Images/image2.png)

Result: the lookup is declared once, in `installations/example/variables.tf`. No other file reads its result. It is declared but never used.

As a result, removing this block (or commenting it out) should not affect how the recipe works. The `terraform plan` that I ran afterwards completed without errors, which supports this.

![image3](/07-Finding-&-Troubleshootings/02-Permission-Denied-Reading-Tenant-Data-Source/Images/image3.png)

---

# Conclusion

My sandbox user is not allowed to read the tenant resource. The recipe asks for it in an unused lookup, so the run fails for no reason. The lookup is not needed, because the tenant ID reaches the modules through a variable.

---

# Workaround

I commented out the three lines of the unused lookup in my installation copy of `variables.tf`:

```hcl
# Demo Day change: removed. Unused lookup, and the sandbox user is not allowed to read the tenant resource.
# data "nebius_iam_v1_tenant" "this" {
#   id = var.iam_tenant_id
# }
```

Result: `terraform plan` completed with `Plan: 47 to add, 0 to change, 0 to destroy.` The only messages left were warnings about a deprecated Nebius project API, which is supported until 16 December 2026 and does not affect the lab.

![image3](/07-Finding-&-Troubleshootings/02-Permission-Denied-Reading-Tenant-Data-Source/Images/image3.png)

---

