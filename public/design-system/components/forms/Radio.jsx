import React from "react";
import { ensureHarpyCss } from "../core/Button.jsx";

const harpyRadioCss = `
.hp-radio{display:inline-flex;align-items:center;gap:8px;font-family:var(--font-sans);font-size:var(--text-base);color:var(--text-body);cursor:pointer;user-select:none;}
.hp-radio input{position:absolute;opacity:0;width:0;height:0;}
.hp-radio__dot{width:16px;height:16px;flex:none;border:1px solid var(--border-strong);border-radius:50%;background:var(--surface-card);position:relative;transition:border-color var(--duration-fast) var(--ease-out);}
.hp-radio__dot::after{content:"";position:absolute;inset:3px;border-radius:50%;background:var(--sun-400);transform:scale(0);transition:transform var(--duration-fast) var(--ease-out);}
.hp-radio input:checked + .hp-radio__dot{border-color:var(--sun-500);}
.hp-radio input:checked + .hp-radio__dot::after{transform:scale(1);}
.hp-radio input:focus-visible + .hp-radio__dot{box-shadow:var(--focus-ring);}
.hp-radio--disabled{opacity:.45;cursor:not-allowed;}
`;

export function Radio({ label, disabled, className = "", style, ...rest }) {
  ensureHarpyCss("hp-radio-css", harpyRadioCss);
  return (
    <label className={`hp-radio ${disabled ? "hp-radio--disabled" : ""} ${className}`} style={style}>
      <input type="radio" disabled={disabled} {...rest}></input>
      <span className="hp-radio__dot"></span>
      {label ? <span>{label}</span> : null}
    </label>
  );
}
