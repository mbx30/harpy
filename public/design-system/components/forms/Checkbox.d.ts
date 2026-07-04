import * as React from "react";

/** Checkbox with built-in label. Checked = amber fill, charcoal check. */
export interface CheckboxProps extends Omit<React.InputHTMLAttributes<HTMLInputElement>, "type"> {
  /** Label text rendered beside the box. */
  label?: React.ReactNode;
}

export declare function Checkbox(props: CheckboxProps): JSX.Element;
