import React from "react";
import { ensureHarpyCss } from "./Button.jsx";

const harpySpinnerCss = `
@keyframes hp-spin { to { transform: rotate(360deg); } }
.hp-spinner{display:inline-block;border-radius:50%;border:2px solid var(--ink-200);border-top-color:var(--sun-500);animation:hp-spin 800ms linear infinite;flex:none;}
`;

export function Spinner({ size = 16, label = "Loading", style, className = "", ...rest }) {
  ensureHarpyCss("hp-spinner-css", harpySpinnerCss);
  return (
    <span
      className={`hp-spinner ${className}`}
      role="progressbar"
      aria-label={label}
      style={{ width: size, height: size, ...style }}
      {...rest}
    ></span>
  );
}
