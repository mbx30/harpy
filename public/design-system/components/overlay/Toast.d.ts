import * as React from "react";

/** Charcoal toast; place fixed at bottom-center, auto-dismiss ~4s. */
export interface ToastProps extends React.HTMLAttributes<HTMLDivElement> {
  /** @default "neutral" */
  variant?: "neutral" | "success" | "error";
  /** Renders a dismiss (×) button when provided. */
  onDismiss?: () => void;
  /** One short sentence. */
  children?: React.ReactNode;
}

export declare function Toast(props: ToastProps): JSX.Element;
