import * as React from "react";

/** Pill status label (the pill echoes the logo pillars). */
export interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** @default "neutral" */
  variant?: "neutral" | "accent" | "success" | "error" | "warning" | "info";
  /** Show a leading status dot. @default false */
  dot?: boolean;
  children?: React.ReactNode;
}

export declare function Badge(props: BadgeProps): JSX.Element;
