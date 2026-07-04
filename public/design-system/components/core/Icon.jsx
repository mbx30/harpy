import React from "react";

/**
 * Tints the vendored Lucide SVGs with currentColor via CSS mask.
 * Set window.HARPY_ICON_BASE if assets/icons lives elsewhere relative to the page.
 */
export function Icon({ name, src, size = 16, base, style, ...rest }) {
  const resolvedBase =
    base ||
    (typeof window !== "undefined" && window.HARPY_ICON_BASE) ||
    "assets/icons";
  const url = src || `${resolvedBase}/${name}.svg`;
  const mask = `url("${url}") center / contain no-repeat`;
  return (
    <span
      aria-hidden="true"
      style={{
        display: "inline-block",
        width: size,
        height: size,
        flex: "none",
        backgroundColor: "currentColor",
        WebkitMask: mask,
        mask: mask,
        ...style,
      }}
      {...rest}
    ></span>
  );
}
