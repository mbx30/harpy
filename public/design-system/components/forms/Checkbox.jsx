import React from "react";
import { ensureHarpyCss } from "../core/Button.jsx";

const harpyCheckboxCss = `
.hp-check{display:inline-flex;align-items:center;gap:8px;font-family:var(--font-sans);font-size:var(--text-base);color:var(--text-body);cursor:pointer;user-select:none;}
.hp-check input{position:absolute;opacity:0;width:0;height:0;}
.hp-check__box{width:16px;height:16px;flex:none;border:1px solid var(--border-strong);border-radius:var(--radius-sm);background:var(--surface-card);position:relative;transition:background var(--duration-fast) var(--ease-out),border-color var(--duration-fast) var(--ease-out);}
.hp-check__box::after{content:"";position:absolute;left:4.5px;top:1.5px;width:4px;height:8px;border:solid var(--ink-900);border-width:0 2px 2px 0;transform:rotate(45deg);opacity:0;}
.hp-check input:checked + .hp-check__box{background:var(--sun-400);border-color:var(--sun-500);}
.hp-check input:checked + .hp-check__box::after{opacity:1;}
.hp-check input:focus-visible + .hp-check__box{box-shadow:var(--focus-ring);}
.hp-check--disabled{opacity:.45;cursor:not-allowed;}
`;

export function Checkbox({ label, disabled, className = "", style, ...rest }) {
  ensureHarpyCss("hp-check-css", harpyCheckboxCss);
  return (
    <label className={`hp-check ${disabled ? "hp-check--disabled" : ""} ${className}`} style={style}>
      <input type="checkbox" disabled={disabled} {...rest}></input>
      <span className="hp-check__box"></span>
      {label ? <span>{label}</span> : null}
    </label>
  );
}
