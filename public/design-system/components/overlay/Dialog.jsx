import React from "react";
import { ensureHarpyCss } from "../core/Button.jsx";
import { IconButton } from "../core/IconButton.jsx";
import { Icon } from "../core/Icon.jsx";

const harpyDialogCss = `
@keyframes hp-dialog-in { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: none; } }
.hp-dialog-scrim{position:fixed;inset:0;background:rgba(25,25,24,0.4);display:flex;align-items:center;justify-content:center;padding:24px;z-index:100;}
.hp-dialog{background:var(--surface-card);border-radius:var(--radius-lg);box-shadow:var(--shadow-overlay);width:100%;max-width:440px;padding:var(--space-6);font-family:var(--font-sans);animation:hp-dialog-in var(--duration-slow) var(--ease-out);}
.hp-dialog__head{display:flex;align-items:flex-start;justify-content:space-between;gap:12px;margin-bottom:8px;}
.hp-dialog__title{margin:0;font-size:var(--text-lg);font-weight:var(--weight-semibold);letter-spacing:var(--tracking-heading);color:var(--text-body);}
.hp-dialog__body{font-size:var(--text-base);color:var(--text-secondary);line-height:var(--leading-normal);}
.hp-dialog__foot{display:flex;justify-content:flex-end;gap:8px;margin-top:var(--space-5);}
`;

export function Dialog({ open, onClose, title, footer, children, className = "", ...rest }) {
  ensureHarpyCss("hp-dialog-css", harpyDialogCss);
  if (!open) return null;
  return (
    <div
      className="hp-dialog-scrim"
      onClick={(e) => {
        if (e.target === e.currentTarget && onClose) onClose();
      }}
    >
      <div className={`hp-dialog ${className}`} role="dialog" aria-modal="true" aria-label={title} {...rest}>
        <div className="hp-dialog__head">
          <h2 className="hp-dialog__title">{title}</h2>
          {onClose ? (
            <IconButton size="sm" aria-label="Close" onClick={onClose}>
              <Icon name="x" size={16} />
            </IconButton>
          ) : null}
        </div>
        <div className="hp-dialog__body">{children}</div>
        {footer ? <div className="hp-dialog__foot">{footer}</div> : null}
      </div>
    </div>
  );
}
