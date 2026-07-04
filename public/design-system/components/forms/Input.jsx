import React from "react";
import { ensureHarpyCss } from "../core/Button.jsx";

const harpyInputCss = `
.hp-input-wrap{position:relative;display:flex;align-items:center;}
.hp-input-wrap__icon{position:absolute;left:10px;color:var(--text-muted);pointer-events:none;display:inline-flex;}
.hp-input{width:100%;height:36px;padding:0 12px;border:1px solid var(--border-strong);border-radius:var(--radius-md);background:var(--surface-card);font-family:var(--font-sans);font-size:var(--text-base);color:var(--text-body);transition:border-color var(--duration-fast) var(--ease-out),box-shadow var(--duration-fast) var(--ease-out);}
.hp-input--with-icon{padding-left:34px;}
.hp-input--mono{font-family:var(--font-mono);font-size:var(--text-sm);}
.hp-input::placeholder{color:var(--text-muted);}
.hp-input:hover:not(:disabled){border-color:var(--ink-400);}
.hp-input:focus{outline:none;border-color:var(--sun-400);box-shadow:var(--focus-ring);}
.hp-input:disabled{background:var(--surface-sunken);color:var(--text-muted);cursor:not-allowed;}
.hp-input--invalid{border-color:var(--status-error);}
.hp-input--invalid:focus{border-color:var(--status-error);box-shadow:0 0 0 2px var(--ink-0),0 0 0 4px var(--status-error);}
`;

export function Input({ icon, invalid = false, mono = false, className = "", style, ...rest }) {
  ensureHarpyCss("hp-input-css", harpyInputCss);
  const input = (
    <input
      className={`hp-input ${icon ? "hp-input--with-icon" : ""} ${invalid ? "hp-input--invalid" : ""} ${mono ? "hp-input--mono" : ""} ${className}`}
      aria-invalid={invalid || undefined}
      style={icon ? undefined : style}
      {...rest}
    ></input>
  );
  if (!icon) return input;
  return (
    <span className="hp-input-wrap" style={style}>
      <span className="hp-input-wrap__icon">{icon}</span>
      {input}
    </span>
  );
}
