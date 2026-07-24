"use client";

import { useActionState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import {
  bootstrapPlatformOwner,
  initialPlatformActionState,
  provisionOrganisation,
} from "../commands";

function ActionMessage({ message, status }: { message?: string; status: "idle" | "success" | "error" }) {
  if (!message) return null;

  return <p className={status === "error" ? "text-sm text-destructive" : "text-sm text-muted-foreground"}>{message}</p>;
}

export function PlatformProvisioning() {
  const [bootstrapState, bootstrapAction, bootstrapPending] = useActionState(
    bootstrapPlatformOwner,
    initialPlatformActionState,
  );
  const [provisionState, provisionAction, provisionPending] = useActionState(
    provisionOrganisation,
    initialPlatformActionState,
  );

  return (
    <div className="grid gap-10 lg:grid-cols-2">
      <section className="space-y-4 border-b pb-8 lg:border-b-0 lg:border-r lg:pr-10">
        <div>
          <h2 className="text-lg font-semibold">Platform owner bootstrap</h2>
          <p className="mt-1 text-sm leading-6 text-muted-foreground">
            Available once to an email address explicitly approved in the server environment.
          </p>
        </div>
        <form action={bootstrapAction}>
          <Button disabled={bootstrapPending} type="submit">
            {bootstrapPending ? "Granting access..." : "Bootstrap platform owner"}
          </Button>
        </form>
        <ActionMessage {...bootstrapState} />
      </section>

      <section className="space-y-4">
        <div>
          <h2 className="text-lg font-semibold">Provision organisation</h2>
          <p className="mt-1 text-sm leading-6 text-muted-foreground">
            Creates the tenant, its first company and branch, an organisation-owner membership, and an implementation record.
          </p>
        </div>
        <form action={provisionAction} className="grid gap-4 sm:grid-cols-2">
          <label className="grid gap-2 sm:col-span-2">
            <Label htmlFor="organisationLegalName">Organisation legal name</Label>
            <Input id="organisationLegalName" name="organisationLegalName" required />
          </label>
          <label className="grid gap-2 sm:col-span-2">
            <Label htmlFor="organisationDisplayName">Organisation display name</Label>
            <Input id="organisationDisplayName" name="organisationDisplayName" required />
          </label>
          <label className="grid gap-2 sm:col-span-2">
            <Label htmlFor="companyLegalName">First company legal name</Label>
            <Input id="companyLegalName" name="companyLegalName" required />
          </label>
          <label className="grid gap-2">
            <Label htmlFor="branchCode">Branch code</Label>
            <Input id="branchCode" maxLength={30} name="branchCode" required />
          </label>
          <label className="grid gap-2">
            <Label htmlFor="branchName">Branch name</Label>
            <Input id="branchName" maxLength={150} name="branchName" required />
          </label>
          <label className="grid gap-2 sm:col-span-2">
            <Label htmlFor="ownerUserId">Organisation owner user ID</Label>
            <Input id="ownerUserId" name="ownerUserId" required type="text" />
          </label>
          <div className="sm:col-span-2">
            <Button disabled={provisionPending} type="submit">
              {provisionPending ? "Provisioning..." : "Provision organisation"}
            </Button>
          </div>
        </form>
        <ActionMessage {...provisionState} />
      </section>
    </div>
  );
}
