import * as React from "react";

/** Charcoal tooltip on hover/focus. Short labels only. */
export interface TooltipProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Tooltip text — a few words. */
  label: string;
  /** @default "top" */
  side?: "top" | "bottom";
  /** The trigger element. */
  children?: React.ReactNode;
}

export declare function Tooltip(props: TooltipProps): JSX.Element;
