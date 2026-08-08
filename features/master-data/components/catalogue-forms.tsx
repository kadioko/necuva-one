"use client";

import { useActionState, type ReactNode } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import {
  addCatalogItemBarcode,
  createItemCategory,
  createUnitConversion,
  createUnitOfMeasure,
  initialMasterDataActionState,
  upsertCatalogItem,
} from "../commands";

type Choice = { id: string; code: string; name: string };

function Message({ message, status }: { message?: string; status: "idle" | "success" | "error" }) {
  if (!message) return null;
  return <p className={status === "error" ? "text-sm text-destructive sm:col-span-2" : "text-sm text-muted-foreground sm:col-span-2"}>{message}</p>;
}

function Select({ children, id, name, required = false }: { children: ReactNode; id: string; name: string; required?: boolean }) {
  return <select className="h-10 rounded-md border bg-background px-3 text-sm" id={id} name={name} required={required}>{children}</select>;
}

export function ItemCategoryForm({ categories, organisationId }: { categories: Choice[]; organisationId: string }) {
  const [state, action, pending] = useActionState(createItemCategory, initialMasterDataActionState);
  return <form action={action} className="grid gap-3 sm:grid-cols-2"><input name="organisationId" type="hidden" value={organisationId} /><label className="grid gap-2"><Label htmlFor="itemCategoryCode">Code</Label><Input id="itemCategoryCode" name="code" required /></label><label className="grid gap-2"><Label htmlFor="itemCategoryName">Name</Label><Input id="itemCategoryName" name="name" required /></label><label className="grid gap-2 sm:col-span-2"><Label htmlFor="itemCategoryParent">Parent category</Label><Select id="itemCategoryParent" name="parentCategoryId"><option value="">None</option>{categories.map((category) => <option key={category.id} value={category.id}>{category.code} - {category.name}</option>)}</Select></label><div className="sm:col-span-2"><Button disabled={pending} type="submit">{pending ? "Creating..." : "Create category"}</Button></div><Message message={state.message} status={state.status} /></form>;
}

export function UnitForm({ organisationId }: { organisationId: string }) {
  const [state, action, pending] = useActionState(createUnitOfMeasure, initialMasterDataActionState);
  return <form action={action} className="grid gap-3 sm:grid-cols-2"><input name="organisationId" type="hidden" value={organisationId} /><label className="grid gap-2"><Label htmlFor="unitCode">Code</Label><Input id="unitCode" name="code" required /></label><label className="grid gap-2"><Label htmlFor="unitName">Name</Label><Input id="unitName" name="name" required /></label><label className="grid gap-2"><Label htmlFor="unitDimension">Dimension</Label><Select id="unitDimension" name="dimension"><option value="count">Count</option><option value="weight">Weight</option><option value="volume">Volume</option><option value="length">Length</option><option value="area">Area</option><option value="time">Time</option><option value="other">Other</option></Select></label><label className="grid gap-2"><Label htmlFor="unitDecimals">Decimal places</Label><Input defaultValue="0" id="unitDecimals" max="6" min="0" name="decimalPlaces" required type="number" /></label><div className="sm:col-span-2"><Button disabled={pending} type="submit">{pending ? "Creating..." : "Create unit"}</Button></div><Message message={state.message} status={state.status} /></form>;
}

export function CatalogItemForm({ categories, organisationId, units }: { categories: Choice[]; organisationId: string; units: Choice[] }) {
  const [state, action, pending] = useActionState(upsertCatalogItem, initialMasterDataActionState);
  return <form action={action} className="grid gap-3 sm:grid-cols-2"><input name="organisationId" type="hidden" value={organisationId} /><label className="grid gap-2"><Label htmlFor="catalogCode">Item code</Label><Input id="catalogCode" name="code" required /></label><label className="grid gap-2"><Label htmlFor="catalogName">Name</Label><Input id="catalogName" name="name" required /></label><label className="grid gap-2"><Label htmlFor="catalogType">Type</Label><Select id="catalogType" name="itemType"><option value="product">Product</option><option value="service">Service</option></Select></label><label className="grid gap-2"><Label htmlFor="catalogUnit">Base unit</Label><Select id="catalogUnit" name="baseUnitId" required><option value="">Choose a unit</option>{units.map((unit) => <option key={unit.id} value={unit.id}>{unit.code} - {unit.name}</option>)}</Select></label><label className="grid gap-2"><Label htmlFor="catalogCategory">Category</Label><Select id="catalogCategory" name="categoryId"><option value="">Uncategorised</option>{categories.map((category) => <option key={category.id} value={category.id}>{category.code} - {category.name}</option>)}</Select></label><label className="grid gap-2"><Label htmlFor="catalogStock">Tracks inventory</Label><Select id="catalogStock" name="tracksInventory"><option value="false">No</option><option value="true">Yes</option></Select></label><label className="grid gap-2 sm:col-span-2"><Label htmlFor="catalogDescription">Description</Label><Input id="catalogDescription" name="description" /></label><label className="grid gap-2"><Label htmlFor="catalogActive">Status</Label><Select id="catalogActive" name="isActive"><option value="true">Active</option><option value="false">Inactive</option></Select></label><div className="self-end"><Button disabled={pending} type="submit">{pending ? "Saving..." : "Save item"}</Button></div><Message message={state.message} status={state.status} /></form>;
}

export function UnitConversionForm({ organisationId, units }: { organisationId: string; units: Choice[] }) {
  const [state, action, pending] = useActionState(createUnitConversion, initialMasterDataActionState);
  return <form action={action} className="grid gap-3 sm:grid-cols-2"><input name="organisationId" type="hidden" value={organisationId} /><label className="grid gap-2"><Label htmlFor="fromUnit">From unit</Label><Select id="fromUnit" name="fromUnitId" required><option value="">Choose a unit</option>{units.map((unit) => <option key={unit.id} value={unit.id}>{unit.code} - {unit.name}</option>)}</Select></label><label className="grid gap-2"><Label htmlFor="toUnit">To unit</Label><Select id="toUnit" name="toUnitId" required><option value="">Choose a unit</option>{units.map((unit) => <option key={unit.id} value={unit.id}>{unit.code} - {unit.name}</option>)}</Select></label><label className="grid gap-2"><Label htmlFor="conversionFactor">Factor</Label><Input id="conversionFactor" name="factor" placeholder="e.g. 1000" required /></label><div className="self-end"><Button disabled={pending} type="submit">{pending ? "Creating..." : "Create conversion"}</Button></div><Message message={state.message} status={state.status} /></form>;
}

export function BarcodeForm({ items, organisationId }: { items: Choice[]; organisationId: string }) {
  const [state, action, pending] = useActionState(addCatalogItemBarcode, initialMasterDataActionState);
  return <form action={action} className="grid gap-3 sm:grid-cols-2"><input name="organisationId" type="hidden" value={organisationId} /><label className="grid gap-2"><Label htmlFor="barcodeItem">Item</Label><Select id="barcodeItem" name="itemId" required><option value="">Choose an item</option>{items.map((item) => <option key={item.id} value={item.id}>{item.code} - {item.name}</option>)}</Select></label><label className="grid gap-2"><Label htmlFor="barcodeValue">Barcode</Label><Input id="barcodeValue" name="barcode" required /></label><label className="grid gap-2"><Label htmlFor="barcodeSymbology">Symbology</Label><Select id="barcodeSymbology" name="symbology"><option value="other">Other</option><option value="ean_13">EAN-13</option><option value="ean_8">EAN-8</option><option value="upc_a">UPC-A</option><option value="code_128">Code 128</option><option value="qr_code">QR code</option></Select></label><label className="grid gap-2"><Label htmlFor="barcodePrimary">Primary</Label><Select id="barcodePrimary" name="isPrimary"><option value="false">No</option><option value="true">Yes</option></Select></label><div className="sm:col-span-2"><Button disabled={pending} type="submit">{pending ? "Adding..." : "Add barcode"}</Button></div><Message message={state.message} status={state.status} /></form>;
}
