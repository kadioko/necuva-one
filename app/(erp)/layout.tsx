import { connection } from "next/server";

import { ErpSidebar } from "@/components/navigation/erp-sidebar";
import { requireUser } from "@/lib/auth/require-user";

export default async function ErpLayout({ children }: { children: React.ReactNode }) {
  await connection();
  const user = await requireUser();

  return (
    <div className="flex min-h-screen bg-muted/30">
      <ErpSidebar />
      <main className="min-w-0 flex-1">
        <header className="flex h-16 items-center justify-between border-b bg-background px-5">
          <span className="font-semibold lg:hidden">Necuva One</span>
          <span className="ml-auto text-sm text-muted-foreground">{user.email}</span>
        </header>
        <div className="mx-auto w-full max-w-7xl p-5 md:p-8">{children}</div>
      </main>
    </div>
  );
}
