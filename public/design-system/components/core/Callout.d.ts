import * as React from "react";

/** Quiet inline status message with a Lucide icon. */
export interface CalloutProps extends React.HTMLAttributes<HTMLDivElement> {
  /** @default "info" */
  variant?: "info" | "success" | "warning" | "error";
  /** Optional bold first line. */
  title?: string;
  children?: React.ReactNode;
}

export declare function Callout(props: CalloutProps): JSX.Element;
