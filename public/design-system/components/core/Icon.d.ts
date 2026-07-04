import * as React from "react";

/** Inline Lucide icon, tinted with currentColor. */
export interface IconProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Icon name from assets/icons (e.g. "check", "copy", "chevron-down"). */
  name?: string;
  /** Explicit SVG url; overrides name/base. */
  src?: string;
  /** Square size in px. @default 16 */
  size?: number;
  /** Path to the icons folder relative to the page. @default "assets/icons" (or window.HARPY_ICON_BASE) */
  base?: string;
}

export declare function Icon(props: IconProps): JSX.Element;
