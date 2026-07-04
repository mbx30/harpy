import * as React from "react";

/** Circular loader — the one permitted infinite animation. */
export interface SpinnerProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Diameter in px. @default 16 */
  size?: number;
  /** Accessible label. @default "Loading" */
  label?: string;
}

export declare function Spinner(props: SpinnerProps): JSX.Element;
