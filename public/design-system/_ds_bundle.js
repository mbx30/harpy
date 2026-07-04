/* @ds-bundle: {"format":3,"namespace":"HarpyDesignSystem_94e4a2","components":[{"name":"Badge","sourcePath":"components/core/Badge.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Callout","sourcePath":"components/core/Callout.jsx"},{"name":"Card","sourcePath":"components/core/Card.jsx"},{"name":"Icon","sourcePath":"components/core/Icon.jsx"},{"name":"IconButton","sourcePath":"components/core/IconButton.jsx"},{"name":"Spinner","sourcePath":"components/core/Spinner.jsx"},{"name":"Tag","sourcePath":"components/core/Tag.jsx"},{"name":"Checkbox","sourcePath":"components/forms/Checkbox.jsx"},{"name":"Field","sourcePath":"components/forms/Field.jsx"},{"name":"Input","sourcePath":"components/forms/Input.jsx"},{"name":"Radio","sourcePath":"components/forms/Radio.jsx"},{"name":"Select","sourcePath":"components/forms/Select.jsx"},{"name":"Switch","sourcePath":"components/forms/Switch.jsx"},{"name":"Tabs","sourcePath":"components/navigation/Tabs.jsx"},{"name":"Dialog","sourcePath":"components/overlay/Dialog.jsx"},{"name":"Toast","sourcePath":"components/overlay/Toast.jsx"},{"name":"Tooltip","sourcePath":"components/overlay/Tooltip.jsx"}],"sourceHashes":{"components/core/Badge.jsx":"6a580a7df05f","components/core/Button.jsx":"feda78c36a12","components/core/Callout.jsx":"d017123a42e1","components/core/Card.jsx":"e755131f30be","components/core/Icon.jsx":"197acd797e56","components/core/IconButton.jsx":"c9c68d4fe25a","components/core/Spinner.jsx":"9f5b5bb7bc64","components/core/Tag.jsx":"74ca3d5777e2","components/forms/Checkbox.jsx":"1253fd1695ab","components/forms/Field.jsx":"12332acc5131","components/forms/Input.jsx":"20b5af421889","components/forms/Radio.jsx":"f7e446c4bffb","components/forms/Select.jsx":"60c6087246d5","components/forms/Switch.jsx":"8778d788e087","components/navigation/Tabs.jsx":"448988633ccd","components/overlay/Dialog.jsx":"d039eff46157","components/overlay/Toast.jsx":"3bb6cbaa4185","components/overlay/Tooltip.jsx":"a9ce871c4532"},"inlinedExternals":[],"unexposedExports":[{"name":"ensureHarpyCss","sourcePath":"components/core/Button.jsx"}]} */

(() => {

const __ds_ns = (window.HarpyDesignSystem_94e4a2 = window.HarpyDesignSystem_94e4a2 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/core/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const harpyButtonCss = `
.hp-btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;border:1px solid transparent;border-radius:var(--radius-md);font-family:var(--font-sans);font-weight:var(--weight-medium);cursor:pointer;transition:background var(--duration-fast) var(--ease-out),border-color var(--duration-fast) var(--ease-out);white-space:nowrap;}
.hp-btn:focus-visible{outline:none;box-shadow:var(--focus-ring);}
.hp-btn:disabled{opacity:.45;cursor:not-allowed;}
.hp-btn--md{height:36px;padding:0 16px;font-size:var(--text-base);}
.hp-btn--sm{height:28px;padding:0 12px;font-size:var(--text-sm);}
.hp-btn--lg{height:44px;padding:0 20px;font-size:var(--text-md);}
.hp-btn--primary{background:var(--accent);color:var(--accent-contrast);}
.hp-btn--primary:hover:not(:disabled){background:var(--accent-hover);}
.hp-btn--primary:active:not(:disabled){background:var(--accent-active);}
.hp-btn--secondary{background:var(--surface-card);border-color:var(--border-strong);color:var(--text-body);}
.hp-btn--secondary:hover:not(:disabled){background:var(--ink-100);}
.hp-btn--secondary:active:not(:disabled){background:var(--ink-200);}
.hp-btn--ghost{background:transparent;color:var(--text-body);}
.hp-btn--ghost:hover:not(:disabled){background:var(--ink-100);}
.hp-btn--ghost:active:not(:disabled){background:var(--ink-200);}
.hp-btn--danger{background:var(--status-error);color:var(--ink-0);}
.hp-btn--danger:hover:not(:disabled){background:var(--red-700);}
.hp-btn--danger:active:not(:disabled){background:var(--red-700);}
`;
function ensureHarpyCss(id, css) {
  if (typeof document === "undefined") return;
  if (document.getElementById(id)) return;
  const el = document.createElement("style");
  el.id = id;
  el.textContent = css;
  document.head.appendChild(el);
}
function Button({
  variant = "primary",
  size = "md",
  icon,
  children,
  className = "",
  ...rest
}) {
  ensureHarpyCss("hp-btn-css", harpyButtonCss);
  return /*#__PURE__*/React.createElement("button", _extends({
    className: `hp-btn hp-btn--${variant} hp-btn--${size} ${className}`
  }, rest), icon, children);
}
Object.assign(__ds_scope, { ensureHarpyCss, Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/Badge.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const harpyBadgeCss = `
.hp-badge{display:inline-flex;align-items:center;gap:6px;height:22px;padding:0 10px;border-radius:var(--radius-pill);font-family:var(--font-sans);font-size:var(--text-xs);font-weight:var(--weight-medium);white-space:nowrap;}
.hp-badge__dot{width:6px;height:6px;border-radius:50%;background:currentColor;}
.hp-badge--neutral{background:var(--ink-100);color:var(--ink-700);}
.hp-badge--accent{background:var(--sun-100);color:var(--sun-700);}
.hp-badge--success{background:var(--status-success-bg);color:var(--status-success-text);}
.hp-badge--error{background:var(--status-error-bg);color:var(--status-error-text);}
.hp-badge--warning{background:var(--status-warning-bg);color:var(--status-warning-text);}
.hp-badge--info{background:var(--status-info-bg);color:var(--status-info-text);}
`;
function Badge({
  variant = "neutral",
  dot = false,
  children,
  className = "",
  ...rest
}) {
  __ds_scope.ensureHarpyCss("hp-badge-css", harpyBadgeCss);
  return /*#__PURE__*/React.createElement("span", _extends({
    className: `hp-badge hp-badge--${variant} ${className}`
  }, rest), dot ? /*#__PURE__*/React.createElement("span", {
    className: "hp-badge__dot"
  }) : null, children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Badge.jsx", error: String((e && e.message) || e) }); }

// components/core/Card.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const harpyCardCss = `
.hp-card{background:var(--surface-card);border:1px solid var(--border-default);border-radius:var(--radius-lg);box-shadow:var(--shadow-sm);padding:var(--space-5);}
.hp-card--interactive{cursor:pointer;transition:border-color var(--duration-base) var(--ease-out),box-shadow var(--duration-base) var(--ease-out);}
.hp-card--interactive:hover{border-color:var(--border-strong);box-shadow:var(--shadow-md);}
.hp-card--flat{box-shadow:none;}
.hp-card--sunken{background:var(--surface-sunken);border:none;box-shadow:none;}
`;
function Card({
  interactive = false,
  variant = "default",
  children,
  className = "",
  ...rest
}) {
  __ds_scope.ensureHarpyCss("hp-card-css", harpyCardCss);
  const variantClass = variant === "flat" ? "hp-card--flat" : variant === "sunken" ? "hp-card--sunken" : "";
  return /*#__PURE__*/React.createElement("div", _extends({
    className: `hp-card ${interactive ? "hp-card--interactive" : ""} ${variantClass} ${className}`
  }, rest), children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Card.jsx", error: String((e && e.message) || e) }); }

// components/core/Icon.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Tints the vendored Lucide SVGs with currentColor via CSS mask.
 * Set window.HARPY_ICON_BASE if assets/icons lives elsewhere relative to the page.
 */
function Icon({
  name,
  src,
  size = 16,
  base,
  style,
  ...rest
}) {
  const resolvedBase = base || typeof window !== "undefined" && window.HARPY_ICON_BASE || "assets/icons";
  const url = src || `${resolvedBase}/${name}.svg`;
  const mask = `url("${url}") center / contain no-repeat`;
  return /*#__PURE__*/React.createElement("span", _extends({
    "aria-hidden": "true",
    style: {
      display: "inline-block",
      width: size,
      height: size,
      flex: "none",
      backgroundColor: "currentColor",
      WebkitMask: mask,
      mask: mask,
      ...style
    }
  }, rest));
}
Object.assign(__ds_scope, { Icon });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Icon.jsx", error: String((e && e.message) || e) }); }

// components/core/Callout.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const harpyCalloutCss = `
.hp-callout{display:flex;gap:10px;padding:12px 14px;border-radius:var(--radius-md);font-family:var(--font-sans);font-size:var(--text-sm);line-height:var(--leading-snug);}
.hp-callout__icon{margin-top:1px;}
.hp-callout__title{font-weight:var(--weight-semibold);margin:0 0 2px;}
.hp-callout--info{background:var(--status-info-bg);color:var(--status-info-text);}
.hp-callout--success{background:var(--status-success-bg);color:var(--status-success-text);}
.hp-callout--warning{background:var(--status-warning-bg);color:var(--status-warning-text);}
.hp-callout--error{background:var(--status-error-bg);color:var(--status-error-text);}
`;
const harpyCalloutIcons = {
  info: "info",
  success: "circle-check",
  warning: "triangle-alert",
  error: "circle-alert"
};
function Callout({
  variant = "info",
  title,
  children,
  className = "",
  ...rest
}) {
  __ds_scope.ensureHarpyCss("hp-callout-css", harpyCalloutCss);
  return /*#__PURE__*/React.createElement("div", _extends({
    className: `hp-callout hp-callout--${variant} ${className}`,
    role: "status"
  }, rest), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    className: "hp-callout__icon",
    name: harpyCalloutIcons[variant],
    size: 16
  }), /*#__PURE__*/React.createElement("div", null, title ? /*#__PURE__*/React.createElement("p", {
    className: "hp-callout__title"
  }, title) : null, /*#__PURE__*/React.createElement("div", null, children)));
}
Object.assign(__ds_scope, { Callout });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Callout.jsx", error: String((e && e.message) || e) }); }

// components/core/IconButton.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const harpyIconButtonCss = `
.hp-iconbtn{display:inline-flex;align-items:center;justify-content:center;border:1px solid transparent;border-radius:var(--radius-md);background:transparent;color:var(--text-secondary);cursor:pointer;transition:background var(--duration-fast) var(--ease-out),color var(--duration-fast) var(--ease-out);}
.hp-iconbtn:hover:not(:disabled){background:var(--ink-100);color:var(--text-body);}
.hp-iconbtn:active:not(:disabled){background:var(--ink-200);}
.hp-iconbtn:focus-visible{outline:none;box-shadow:var(--focus-ring);}
.hp-iconbtn:disabled{opacity:.45;cursor:not-allowed;}
.hp-iconbtn--outline{border-color:var(--border-strong);background:var(--surface-card);}
.hp-iconbtn--sm{width:28px;height:28px;}
.hp-iconbtn--md{width:36px;height:36px;}
.hp-iconbtn--lg{width:44px;height:44px;}
`;
function IconButton({
  variant = "ghost",
  size = "md",
  "aria-label": ariaLabel,
  children,
  className = "",
  ...rest
}) {
  __ds_scope.ensureHarpyCss("hp-iconbtn-css", harpyIconButtonCss);
  return /*#__PURE__*/React.createElement("button", _extends({
    className: `hp-iconbtn hp-iconbtn--${variant} hp-iconbtn--${size} ${className}`,
    "aria-label": ariaLabel
  }, rest), children);
}
Object.assign(__ds_scope, { IconButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/IconButton.jsx", error: String((e && e.message) || e) }); }

// components/core/Spinner.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const harpySpinnerCss = `
@keyframes hp-spin { to { transform: rotate(360deg); } }
.hp-spinner{display:inline-block;border-radius:50%;border:2px solid var(--ink-200);border-top-color:var(--sun-500);animation:hp-spin 800ms linear infinite;flex:none;}
`;
function Spinner({
  size = 16,
  label = "Loading",
  style,
  className = "",
  ...rest
}) {
  __ds_scope.ensureHarpyCss("hp-spinner-css", harpySpinnerCss);
  return /*#__PURE__*/React.createElement("span", _extends({
    className: `hp-spinner ${className}`,
    role: "progressbar",
    "aria-label": label,
    style: {
      width: size,
      height: size,
      ...style
    }
  }, rest));
}
Object.assign(__ds_scope, { Spinner });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Spinner.jsx", error: String((e && e.message) || e) }); }

// components/core/Tag.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const harpyTagCss = `
.hp-tag{display:inline-flex;align-items:center;gap:6px;height:24px;padding:0 4px 0 10px;border-radius:var(--radius-pill);border:1px solid var(--border-default);background:var(--surface-card);font-family:var(--font-sans);font-size:var(--text-xs);font-weight:var(--weight-medium);color:var(--text-body);white-space:nowrap;}
.hp-tag--plain{padding-right:10px;}
.hp-tag__x{display:inline-flex;align-items:center;justify-content:center;width:16px;height:16px;border:none;border-radius:50%;background:transparent;color:var(--text-muted);cursor:pointer;transition:background var(--duration-fast) var(--ease-out),color var(--duration-fast) var(--ease-out);padding:0;}
.hp-tag__x:hover{background:var(--ink-100);color:var(--text-body);}
.hp-tag__x:focus-visible{outline:none;box-shadow:var(--focus-ring);}
`;
function Tag({
  onRemove,
  children,
  className = "",
  ...rest
}) {
  __ds_scope.ensureHarpyCss("hp-tag-css", harpyTagCss);
  return /*#__PURE__*/React.createElement("span", _extends({
    className: `hp-tag ${onRemove ? "" : "hp-tag--plain"} ${className}`
  }, rest), children, onRemove ? /*#__PURE__*/React.createElement("button", {
    type: "button",
    className: "hp-tag__x",
    "aria-label": "Remove",
    onClick: onRemove
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "x",
    size: 11
  })) : null);
}
Object.assign(__ds_scope, { Tag });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Tag.jsx", error: String((e && e.message) || e) }); }

// components/forms/Checkbox.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
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
function Checkbox({
  label,
  disabled,
  className = "",
  style,
  ...rest
}) {
  __ds_scope.ensureHarpyCss("hp-check-css", harpyCheckboxCss);
  return /*#__PURE__*/React.createElement("label", {
    className: `hp-check ${disabled ? "hp-check--disabled" : ""} ${className}`,
    style: style
  }, /*#__PURE__*/React.createElement("input", _extends({
    type: "checkbox",
    disabled: disabled
  }, rest)), /*#__PURE__*/React.createElement("span", {
    className: "hp-check__box"
  }), label ? /*#__PURE__*/React.createElement("span", null, label) : null);
}
Object.assign(__ds_scope, { Checkbox });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Checkbox.jsx", error: String((e && e.message) || e) }); }

// components/forms/Field.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const harpyFieldCss = `
.hp-field{display:flex;flex-direction:column;gap:6px;font-family:var(--font-sans);}
.hp-field__label{font-size:var(--text-sm);font-weight:var(--weight-medium);color:var(--text-body);}
.hp-field__optional{font-weight:var(--weight-regular);color:var(--text-muted);}
.hp-field__hint{font-size:var(--text-xs);color:var(--text-muted);margin:0;}
.hp-field__error{font-size:var(--text-xs);color:var(--status-error-text);margin:0;}
`;
function Field({
  label,
  hint,
  error,
  optional = false,
  htmlFor,
  children,
  className = "",
  ...rest
}) {
  __ds_scope.ensureHarpyCss("hp-field-css", harpyFieldCss);
  return /*#__PURE__*/React.createElement("div", _extends({
    className: `hp-field ${className}`
  }, rest), label ? /*#__PURE__*/React.createElement("label", {
    className: "hp-field__label",
    htmlFor: htmlFor
  }, label, " ", optional ? /*#__PURE__*/React.createElement("span", {
    className: "hp-field__optional"
  }, "\u2014 optional") : null) : null, children, error ? /*#__PURE__*/React.createElement("p", {
    className: "hp-field__error"
  }, error) : hint ? /*#__PURE__*/React.createElement("p", {
    className: "hp-field__hint"
  }, hint) : null);
}
Object.assign(__ds_scope, { Field });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Field.jsx", error: String((e && e.message) || e) }); }

// components/forms/Input.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
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
function Input({
  icon,
  invalid = false,
  mono = false,
  className = "",
  style,
  ...rest
}) {
  __ds_scope.ensureHarpyCss("hp-input-css", harpyInputCss);
  const input = /*#__PURE__*/React.createElement("input", _extends({
    className: `hp-input ${icon ? "hp-input--with-icon" : ""} ${invalid ? "hp-input--invalid" : ""} ${mono ? "hp-input--mono" : ""} ${className}`,
    "aria-invalid": invalid || undefined,
    style: icon ? undefined : style
  }, rest));
  if (!icon) return input;
  return /*#__PURE__*/React.createElement("span", {
    className: "hp-input-wrap",
    style: style
  }, /*#__PURE__*/React.createElement("span", {
    className: "hp-input-wrap__icon"
  }, icon), input);
}
Object.assign(__ds_scope, { Input });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Input.jsx", error: String((e && e.message) || e) }); }

// components/forms/Radio.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
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
function Radio({
  label,
  disabled,
  className = "",
  style,
  ...rest
}) {
  __ds_scope.ensureHarpyCss("hp-radio-css", harpyRadioCss);
  return /*#__PURE__*/React.createElement("label", {
    className: `hp-radio ${disabled ? "hp-radio--disabled" : ""} ${className}`,
    style: style
  }, /*#__PURE__*/React.createElement("input", _extends({
    type: "radio",
    disabled: disabled
  }, rest)), /*#__PURE__*/React.createElement("span", {
    className: "hp-radio__dot"
  }), label ? /*#__PURE__*/React.createElement("span", null, label) : null);
}
Object.assign(__ds_scope, { Radio });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Radio.jsx", error: String((e && e.message) || e) }); }

// components/forms/Select.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const harpySelectCss = `
.hp-select-wrap{position:relative;display:inline-flex;width:100%;}
.hp-select{appearance:none;width:100%;height:36px;padding:0 34px 0 12px;border:1px solid var(--border-strong);border-radius:var(--radius-md);background:var(--surface-card);font-family:var(--font-sans);font-size:var(--text-base);color:var(--text-body);cursor:pointer;transition:border-color var(--duration-fast) var(--ease-out);}
.hp-select:hover:not(:disabled){border-color:var(--ink-400);}
.hp-select:focus{outline:none;border-color:var(--sun-400);box-shadow:var(--focus-ring);}
.hp-select:disabled{background:var(--surface-sunken);color:var(--text-muted);cursor:not-allowed;}
.hp-select-wrap__chevron{position:absolute;right:10px;top:50%;transform:translateY(-50%);color:var(--text-muted);pointer-events:none;display:inline-flex;}
`;
function Select({
  children,
  className = "",
  style,
  ...rest
}) {
  __ds_scope.ensureHarpyCss("hp-select-css", harpySelectCss);
  return /*#__PURE__*/React.createElement("span", {
    className: "hp-select-wrap",
    style: style
  }, /*#__PURE__*/React.createElement("select", _extends({
    className: `hp-select ${className}`
  }, rest), children), /*#__PURE__*/React.createElement("span", {
    className: "hp-select-wrap__chevron"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevron-down",
    size: 16
  })));
}
Object.assign(__ds_scope, { Select });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Select.jsx", error: String((e && e.message) || e) }); }

// components/forms/Switch.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
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
function Switch({
  label,
  disabled,
  className = "",
  style,
  ...rest
}) {
  __ds_scope.ensureHarpyCss("hp-switch-css", harpySwitchCss);
  return /*#__PURE__*/React.createElement("label", {
    className: `hp-switch ${disabled ? "hp-switch--disabled" : ""} ${className}`,
    style: style
  }, /*#__PURE__*/React.createElement("input", _extends({
    type: "checkbox",
    role: "switch",
    disabled: disabled
  }, rest)), /*#__PURE__*/React.createElement("span", {
    className: "hp-switch__track"
  }), label ? /*#__PURE__*/React.createElement("span", null, label) : null);
}
Object.assign(__ds_scope, { Switch });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Switch.jsx", error: String((e && e.message) || e) }); }

// components/navigation/Tabs.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const harpyTabsCss = `
.hp-tabs{display:flex;gap:4px;border-bottom:1px solid var(--border-default);font-family:var(--font-sans);}
.hp-tab{appearance:none;background:transparent;border:none;border-bottom:2px solid transparent;margin-bottom:-1px;padding:8px 12px;font-size:var(--text-base);font-weight:var(--weight-medium);color:var(--text-secondary);cursor:pointer;transition:color var(--duration-fast) var(--ease-out),border-color var(--duration-fast) var(--ease-out);}
.hp-tab:hover{color:var(--text-body);}
.hp-tab:focus-visible{outline:none;box-shadow:var(--focus-ring);border-radius:var(--radius-sm);}
.hp-tab--active{color:var(--text-body);border-bottom-color:var(--sun-400);}
`;
function Tabs({
  tabs,
  value,
  defaultValue,
  onChange,
  className = "",
  ...rest
}) {
  __ds_scope.ensureHarpyCss("hp-tabs-css", harpyTabsCss);
  const [internal, setInternal] = React.useState(defaultValue ?? (tabs[0] && tabs[0].value));
  const active = value !== undefined ? value : internal;
  const select = v => {
    if (value === undefined) setInternal(v);
    if (onChange) onChange(v);
  };
  return /*#__PURE__*/React.createElement("div", _extends({
    className: `hp-tabs ${className}`,
    role: "tablist"
  }, rest), tabs.map(t => /*#__PURE__*/React.createElement("button", {
    key: t.value,
    type: "button",
    role: "tab",
    "aria-selected": active === t.value,
    className: `hp-tab ${active === t.value ? "hp-tab--active" : ""}`,
    onClick: () => select(t.value)
  }, t.label)));
}
Object.assign(__ds_scope, { Tabs });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/Tabs.jsx", error: String((e && e.message) || e) }); }

// components/overlay/Dialog.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const harpyDialogCss = `
@keyframes hp-dialog-in { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: none; } }
.hp-dialog-scrim{position:fixed;inset:0;background:rgba(25,25,24,0.4);display:flex;align-items:center;justify-content:center;padding:24px;z-index:100;}
.hp-dialog{background:var(--surface-card);border-radius:var(--radius-lg);box-shadow:var(--shadow-overlay);width:100%;max-width:440px;padding:var(--space-6);font-family:var(--font-sans);animation:hp-dialog-in var(--duration-slow) var(--ease-out);}
.hp-dialog__head{display:flex;align-items:flex-start;justify-content:space-between;gap:12px;margin-bottom:8px;}
.hp-dialog__title{margin:0;font-size:var(--text-lg);font-weight:var(--weight-semibold);letter-spacing:var(--tracking-heading);color:var(--text-body);}
.hp-dialog__body{font-size:var(--text-base);color:var(--text-secondary);line-height:var(--leading-normal);}
.hp-dialog__foot{display:flex;justify-content:flex-end;gap:8px;margin-top:var(--space-5);}
`;
function Dialog({
  open,
  onClose,
  title,
  footer,
  children,
  className = "",
  ...rest
}) {
  __ds_scope.ensureHarpyCss("hp-dialog-css", harpyDialogCss);
  if (!open) return null;
  return /*#__PURE__*/React.createElement("div", {
    className: "hp-dialog-scrim",
    onClick: e => {
      if (e.target === e.currentTarget && onClose) onClose();
    }
  }, /*#__PURE__*/React.createElement("div", _extends({
    className: `hp-dialog ${className}`,
    role: "dialog",
    "aria-modal": "true",
    "aria-label": title
  }, rest), /*#__PURE__*/React.createElement("div", {
    className: "hp-dialog__head"
  }, /*#__PURE__*/React.createElement("h2", {
    className: "hp-dialog__title"
  }, title), onClose ? /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    size: "sm",
    "aria-label": "Close",
    onClick: onClose
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "x",
    size: 16
  })) : null), /*#__PURE__*/React.createElement("div", {
    className: "hp-dialog__body"
  }, children), footer ? /*#__PURE__*/React.createElement("div", {
    className: "hp-dialog__foot"
  }, footer) : null));
}
Object.assign(__ds_scope, { Dialog });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/overlay/Dialog.jsx", error: String((e && e.message) || e) }); }

// components/overlay/Toast.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const harpyToastCss = `
@keyframes hp-toast-in { from { opacity: 0; transform: translateY(6px); } to { opacity: 1; transform: none; } }
.hp-toast{display:flex;align-items:center;gap:10px;background:var(--surface-inverse);color:var(--text-inverse);border-radius:var(--radius-md);box-shadow:var(--shadow-lg);padding:10px 12px;font-family:var(--font-sans);font-size:var(--text-sm);font-weight:var(--weight-medium);max-width:360px;animation:hp-toast-in var(--duration-slow) var(--ease-out);}
.hp-toast__icon--success{color:var(--sun-400);}
.hp-toast__icon--error{color:#E58B75;}
.hp-toast__msg{flex:1;}
.hp-toast .hp-iconbtn{color:var(--ink-400);}
.hp-toast .hp-iconbtn:hover:not(:disabled){background:var(--ink-800);color:var(--ink-0);}
`;
const harpyToastIcons = {
  success: "circle-check",
  error: "circle-alert",
  neutral: "info"
};
function Toast({
  variant = "neutral",
  onDismiss,
  children,
  className = "",
  ...rest
}) {
  __ds_scope.ensureHarpyCss("hp-toast-css", harpyToastCss);
  return /*#__PURE__*/React.createElement("div", _extends({
    className: `hp-toast ${className}`,
    role: "status"
  }, rest), /*#__PURE__*/React.createElement("span", {
    className: `hp-toast__icon--${variant}`,
    style: {
      display: "inline-flex"
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: harpyToastIcons[variant],
    size: 16
  })), /*#__PURE__*/React.createElement("span", {
    className: "hp-toast__msg"
  }, children), onDismiss ? /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    size: "sm",
    "aria-label": "Dismiss",
    onClick: onDismiss
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "x",
    size: 14
  })) : null);
}
Object.assign(__ds_scope, { Toast });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/overlay/Toast.jsx", error: String((e && e.message) || e) }); }

// components/overlay/Tooltip.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const harpyTooltipCss = `
.hp-tooltip-wrap{position:relative;display:inline-flex;}
.hp-tooltip{position:absolute;bottom:calc(100% + 6px);left:50%;transform:translateX(-50%) translateY(2px);background:var(--surface-inverse);color:var(--text-inverse);font-family:var(--font-sans);font-size:var(--text-xs);font-weight:var(--weight-medium);line-height:1.3;padding:5px 8px;border-radius:var(--radius-sm);white-space:nowrap;pointer-events:none;opacity:0;transition:opacity var(--duration-fast) var(--ease-out),transform var(--duration-fast) var(--ease-out);z-index:50;}
.hp-tooltip-wrap:hover .hp-tooltip,.hp-tooltip-wrap:focus-within .hp-tooltip{opacity:1;transform:translateX(-50%) translateY(0);}
.hp-tooltip--bottom{bottom:auto;top:calc(100% + 6px);}
`;
function Tooltip({
  label,
  side = "top",
  children,
  className = "",
  ...rest
}) {
  __ds_scope.ensureHarpyCss("hp-tooltip-css", harpyTooltipCss);
  return /*#__PURE__*/React.createElement("span", _extends({
    className: `hp-tooltip-wrap ${className}`
  }, rest), children, /*#__PURE__*/React.createElement("span", {
    className: `hp-tooltip ${side === "bottom" ? "hp-tooltip--bottom" : ""}`,
    role: "tooltip"
  }, label));
}
Object.assign(__ds_scope, { Tooltip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/overlay/Tooltip.jsx", error: String((e && e.message) || e) }); }

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Callout = __ds_scope.Callout;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.Icon = __ds_scope.Icon;

__ds_ns.IconButton = __ds_scope.IconButton;

__ds_ns.Spinner = __ds_scope.Spinner;

__ds_ns.Tag = __ds_scope.Tag;

__ds_ns.Checkbox = __ds_scope.Checkbox;

__ds_ns.Field = __ds_scope.Field;

__ds_ns.Input = __ds_scope.Input;

__ds_ns.Radio = __ds_scope.Radio;

__ds_ns.Select = __ds_scope.Select;

__ds_ns.Switch = __ds_scope.Switch;

__ds_ns.Tabs = __ds_scope.Tabs;

__ds_ns.Dialog = __ds_scope.Dialog;

__ds_ns.Toast = __ds_scope.Toast;

__ds_ns.Tooltip = __ds_scope.Tooltip;

})();
