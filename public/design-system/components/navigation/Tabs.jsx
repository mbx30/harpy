import React from "react";
import { ensureHarpyCss } from "../core/Button.jsx";

const harpyTabsCss = `
.hp-tabs{display:flex;gap:4px;border-bottom:1px solid var(--border-default);font-family:var(--font-sans);}
.hp-tab{appearance:none;background:transparent;border:none;border-bottom:2px solid transparent;margin-bottom:-1px;padding:8px 12px;font-size:var(--text-base);font-weight:var(--weight-medium);color:var(--text-secondary);cursor:pointer;transition:color var(--duration-fast) var(--ease-out),border-color var(--duration-fast) var(--ease-out);}
.hp-tab:hover{color:var(--text-body);}
.hp-tab:focus-visible{outline:none;box-shadow:var(--focus-ring);border-radius:var(--radius-sm);}
.hp-tab--active{color:var(--text-body);border-bottom-color:var(--sun-400);}
`;

export function Tabs({ tabs, value, defaultValue, onChange, className = "", ...rest }) {
  ensureHarpyCss("hp-tabs-css", harpyTabsCss);
  const [internal, setInternal] = React.useState(defaultValue ?? (tabs[0] && tabs[0].value));
  const active = value !== undefined ? value : internal;
  const select = (v) => {
    if (value === undefined) setInternal(v);
    if (onChange) onChange(v);
  };
  return (
    <div className={`hp-tabs ${className}`} role="tablist" {...rest}>
      {tabs.map((t) => (
        <button
          key={t.value}
          type="button"
          role="tab"
          aria-selected={active === t.value}
          className={`hp-tab ${active === t.value ? "hp-tab--active" : ""}`}
          onClick={() => select(t.value)}
        >
          {t.label}
        </button>
      ))}
    </div>
  );
}
