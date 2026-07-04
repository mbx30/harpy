import React from "react";
import { ensureHarpyCss } from "../core/Button.jsx";

const harpySwitchCss = `
.hp-switch{display:inline-flex;align-items:center;gap:8px;font-family:var(--font-sans);font-size:var(--text-base);color:var(--text-body);cursor:pointer;user-select:none;}
.hp-switch input{position:absolute;opacity:0;width:0;height:0;}
.hp-switch__track{width:32px;height:18px;flex:none;border-radius:var(--radius-pill);background:var(--ink-300);position:relative;transition:background var(--duration-base) var(--ease-out);}
.hp-switch__track::after{content:"";position:absolute;top:2px;left:2px;width:14px;height:14px;border-radius:50%;background:var(--ink-0);box-shadow:var(--shadow-sm);transition:transform var(--duration-base) var(--ease-out);}
.hp-switch input:checked + .hp-switch__track{background:var(--sun-400);}
.hp-switch input:checked + .hp-switch__track::after{transform:translateX(14px);}
.hp-switch input:focus-visible + .hp-switch__track{box-shadow:var(--focus-ring);}
.hp-switch--disabled{opacity:.45;cursor:not-allowed;}
`;

export function Switch({ label, disabled, className = "", style, ...rest }) {
  ensureHarpyCss("hp-switch-css", harpySwitchCss);
  return (
    <label className={`hp-switch ${disabled ? "hp-switch--disabled" : ""} ${className}`} style={style}>
      <input type="checkbox" role="switch" disabled={disabled} {...rest}></input>
      <span className="hp-switch__track"></span>
      {label ? <span>{label}</span> : null}
    </label>
  );
}
