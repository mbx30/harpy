import React from "react";
import { ensureHarpyCss } from "../core/Button.jsx";

const harpyFieldCss = `
.hp-field{display:flex;flex-direction:column;gap:6px;font-family:var(--font-sans);}
.hp-field__label{font-size:var(--text-sm);font-weight:var(--weight-medium);color:var(--text-body);}
.hp-field__optional{font-weight:var(--weight-regular);color:var(--text-muted);}
.hp-field__hint{font-size:var(--text-xs);color:var(--text-muted);margin:0;}
.hp-field__error{font-size:var(--text-xs);color:var(--status-error-text);margin:0;}
`;

export function Field({ label, hint, error, optional = false, htmlFor, children, className = "", ...rest }) {
  ensureHarpyCss("hp-field-css", harpyFieldCss);
  return (
    <div className={`hp-field ${className}`} {...rest}>
      {label ? (
        <label className="hp-field__label" htmlFor={htmlFor}>
          {label} {optional ? <span className="hp-field__optional">— optional</span> : null}
        </label>
      ) : null}
      {children}
      {error ? <p className="hp-field__error">{error}</p> : hint ? <p className="hp-field__hint">{hint}</p> : null}
    </div>
  );
}
