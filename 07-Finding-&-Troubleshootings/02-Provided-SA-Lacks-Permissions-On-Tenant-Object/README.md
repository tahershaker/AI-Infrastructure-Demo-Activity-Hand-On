# 02 - Provided Service Account Lacks Permissions On Tenant Object

> `terraform plan` failed with `PermissionDenied` while reading the tenant resource. The Soperator recipe declares a lookup of the tenant, but nothing in the code uses the result. My sandbox user cannot read the tenant, so I commented out the unused lookup in my installation copy of `variables.tf`. After this, `terraform plan` completed.

---

# Issue Summary

- The recipe has a `data` block that asks Nebius to read the tenant `csa-hiring-sandbox`.
- The provided services account can work inside the project, but cannot read the tenant itself.
- Terraform runs every `data` block during the plan, so the `PermissionDenied` error stopped the whole run.
- A search of the release shows that nothing uses the result of this lookup.
- I commented out the lookup in my installation copy. The plan then completed.

---

# Questions to Nebius team

1. Is commeting the data block is the expected approach?
2. If not, should I ask the Nebius team to update the permissions of the provided service accounts? My user permission on tenant itself, so I cannot fix this myself.

---

# Issue Description

After `terraform init` succeeded (see [01-Provided-Service-Account-Lacks-Required-Permissions](/07-Finding-&-Troubleshootings/01-Provided-SA-Lacks-Required-Permissions/README.md)), I ran `terraform plan`. It stopped with this error:

```text
Error: datasource reading by ID failed

  with data.nebius_iam_v1_tenant.this,
  on variables.tf line 50, in data "nebius_iam_v1_tenant" "this":
  50:   id = var.iam_tenant_id

datasource reading by ID failed: service get: rpc error: code = PermissionDenied desc = No permission
```

![image1](/07-Finding-&-Troubleshootings/02-Provided-SA-Lacks-Permissions-On-Tenant-Object/Images/image1.png)

Terraform asked Nebius to read the tenant `csa-hiring-sandbox`, and the provided service account is not allowed to do that. It is the same kind of limit as in issue 01. The provided service account can work inside the project, but not on the tenant itself.

---

# Troubleshooting steps

## Step 1: Find out what the lookup is

The error names the file and the line. In my installation folder, `variables.tf` has this block:

```hcl
data "nebius_iam_v1_tenant" "this" {
  id = var.iam_tenant_id
}
```

A `data` block creates nothing. It only asks Nebius for information about something that already exists, so that Terraform can use the answer elsewhere. In plain words, it says: "Ask Nebius for the tenant with this ID, and keep the answer under the name `this`."

Terraform reads every `data` block during the plan, even when nothing uses the answer. So this lookup ran, my user was not allowed to read the tenant, and the run stopped.

The next step is to check if anything uses the answer.

---

## Step 2: Check whether anything uses the result

I searched the whole Soperator release (v4.1.13-2) for any use of this lookup:

```bash
grep -rn "nebius_iam_v1_tenant" .
grep -rn "tenant\.this" .
```

![image2](/07-Finding-&-Troubleshootings/02-Provided-SA-Lacks-Permissions-On-Tenant-Object/Images/image2.png)

Result: the lookup is declared once, in `installations/example/variables.tf`. No other file reads its result. It is declared but never used.

---

## Step 3: Test the plan without the lookup

I commented out the lookup (see Workaround) and ran `terraform plan` again. It completed with no errors:

```text
Plan: 47 to add, 0 to change, 0 to destroy.
```

![image3](/07-Finding-&-Troubleshootings/02-Provided-SA-Lacks-Permissions-On-Tenant-Object/Images/image3.png)

---

# Conclusion

The provided service account is not allowed to read the tenant resource. The recipe asks for it in a lookup that nothing uses, so the run fails for no reason. The tenant ID is still available as `var.iam_tenant_id`, and the plan works without the lookup.

---

# Workaround

I commented out the three lines of the unused lookup in my installation copy of `variables.tf`:

```hcl
# Demo Day change: removed. Unused lookup, and the sandbox user is not allowed to read the tenant resource.
# data "nebius_iam_v1_tenant" "this" {
#   id = var.iam_tenant_id
# }
```

Result: `terraform plan` completed with `Plan: 47 to add, 0 to change, 0 to destroy.` See Step 3.

---