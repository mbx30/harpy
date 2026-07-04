import * as React from "react";

/** Radio button with built-in label; amber dot when selected. */
export interface RadioProps extends Omit<React.InputHTMLAttributes<HTMLInputElement>, "type"> {
  /** Label text rendered beside the dot. */
  label?: React.ReactNode;
}

export declare function Radio(props: RadioProps): JSX.Element;
