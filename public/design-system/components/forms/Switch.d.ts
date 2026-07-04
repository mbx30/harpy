import * as React from "react";

/** Toggle switch; amber track when on. */
export interface SwitchProps extends Omit<React.InputHTMLAttributes<HTMLInputElement>, "type"> {
  /** Label text rendered beside the track. */
  label?: React.ReactNode;
}

export declare function Switch(props: SwitchProps): JSX.Element;
