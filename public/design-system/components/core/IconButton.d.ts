import * as React from "react";

/** Square icon-only button. Always pass aria-label. */
export interface IconButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  /** @default "ghost" */
  variant?: "ghost" | "outline";
  /** @default "md" */
  size?: "sm" | "md" | "lg";
  /** Required accessible name. */
  "aria-label": string;
  /** The icon node. */
  children?: React.ReactNode;
}

export declare function IconButton(props: IconButtonProps): JSX.Element;
