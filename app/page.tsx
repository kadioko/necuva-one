import { EnvVarWarning } from "@/components/env-var-warning";
import { AuthButton } from "@/components/auth-button";
import { hasEnvVars } from "@/lib/utils";
import Link from "next/link";
import { Suspense } from "react";

export default function Home() {
  return (
    <main className="min-h-screen flex flex-col items-center">
      <div className="flex-1 w-full flex flex-col items-center">
        <nav className="w-full flex justify-center border-b border-b-foreground/10 h-16">
          <div className="w-full max-w-5xl flex justify-between items-center p-3 px-5 text-sm">
            <Link className="font-semibold" href={"/"}>Necuva One</Link>
            {!hasEnvVars ? (
              <EnvVarWarning />
            ) : (
              <Suspense>
                <AuthButton />
              </Suspense>
            )}
          </div>
        </nav>
        <main className="w-full max-w-5xl flex-1 px-5 py-20">
          <p className="text-sm font-medium text-muted-foreground">Necuva Group Limited</p>
          <h1 className="mt-3 text-3xl font-semibold tracking-normal">Necuva One</h1>
          <p className="mt-4 max-w-2xl text-sm leading-6 text-muted-foreground">
            A secure, multi-tenant ERP foundation for Tanzanian organisations.
          </p>
        </main>
      </div>
    </main>
  );
}
