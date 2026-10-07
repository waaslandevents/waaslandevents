import type { ReactNode } from "react";

/** Leeg scherm = uitnodiging om iets te doen. */
export function EmptyState({ title, children, action }: { title: string; children?: ReactNode; action?: ReactNode }) {
  return (
    <div className="rounded-lg border border-dashed border-line-strong bg-surface px-6 py-12 text-center">
      <h3 className="text-lg">{title}</h3>
      {children && <p className="mx-auto mt-2 max-w-md text-ink-muted">{children}</p>}
      {action && <div className="mt-6 flex justify-center">{action}</div>}
    </div>
  );
}
