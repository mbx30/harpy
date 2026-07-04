import React from "react";
import { ensureHarpyCss } from "./Button.jsx";

const harpyCardCss = `
.hp-card{background:var(--surface-card);border:1px solid var(--border-default);border-radius:var(--radius-lg);box-shadow:var(--shadow-sm);padding:var(--space-5);}
.hp-card--interactive{cursor:pointer;transition:border-color var(--duration-base) var(--ease-out),box-shadow var(--duration-base) var(--ease-out);}
.hp-card--interactive:hover{border-color:var(--border-strong);box-shadow:var(--shadow-md);}
.hp-card--flat{box-shadow:none;}
.hp-card--sunken{background:var(--surface-sunken);border:none;box-shadow:none;}
`;

export function Card({ interactive = false, variant = "default", children, className = "", ...rest }) {
  ensureHarpyCss("hp-card-css", harpyCardCss);
  const variantClass =
    variant === "flat" ? "hp-card--flat" : variant === "sunken" ? "hp-card--sunken" : "";
  return (
    <div
      className={`hp-card ${interactive ? "hp-card--interactive" : ""} ${variantClass} ${className}`}
      {...rest}
    >
      {children}
    </div>
  );
}
