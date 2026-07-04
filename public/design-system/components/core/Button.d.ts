import * as React from "react";

/**
 * Harpy button. Amber = the one loud thing on a quiet page.
 * @startingPoint section="Core" subtitle="Primary, secondary, ghost, danger buttons" viewport="700x220"
 */
export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  /** Visual style. @default "primary" */
  variant?: "primary" | "secondary" | "ghost" | "danger";
  /** Control height: 28 / 36 / 44px. @default "md" */
  size?: "sm" | "md" | "lg";
  /** Leading icon node (use <Icon name="…" size={16} />). */
  icon?: React.ReactNode;
  children?: React.ReactNode;
}

export declare function Button(props: ButtonProps): JSX.Element;
