import Link from "next/link";
import { Barcode, Building2, ClipboardList, Database, Landmark, LayoutDashboard, Settings, ShieldCheck } from "lucide-react";

const navigation = [
  { href: "/erp", label: "Overview", icon: LayoutDashboard },
  { href: "/onboarding", label: "Onboarding", icon: Building2 },
  { href: "/erp/audit", label: "Audit trail", icon: ClipboardList },
  { href: "/erp/master-data/parties", label: "Parties", icon: Database },
  { href: "/erp/master-data/catalogue", label: "Item catalogue", icon: Barcode },
  { href: "/erp/master-data/payments", label: "Payment references", icon: Landmark },
  { href: "/erp/master-data/localisation", label: "Localisation", icon: Database },
  { href: "/admin", label: "Control Centre", icon: ShieldCheck },
  { href: "/erp/settings", label: "Settings", icon: Settings },
];

export function ErpSidebar() {
  return (
    <aside className="hidden w-60 shrink-0 border-r bg-card lg:block">
      <div className="flex h-16 items-center border-b px-5 font-semibold">Necuva One</div>
      <nav className="space-y-1 p-3" aria-label="Primary navigation">
        {navigation.map(({ href, label, icon: Icon }) => (
          <Link
            className="flex h-10 items-center gap-3 rounded-md px-3 text-sm text-muted-foreground hover:bg-muted hover:text-foreground"
            href={href}
            key={href}
          >
            <Icon aria-hidden="true" className="size-4" />
            {label}
          </Link>
        ))}
      </nav>
    </aside>
  );
}
