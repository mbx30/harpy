import * as React from "react";

/** Label + hint/error wrapper around any control. */
export interface FieldProps extends React.HTMLAttributes<HTMLDivElement> {
  label?: string;
  /** Muted helper line below the control. */
  hint?: string;
  /** Replaces hint; renders in error red. */
  error?: string;
  /** Appends "— optional" to the label. @default false */
  optional?: boolean;
  /** id of the wrapped control. */
  htmlFor?: string;
  children?: React.ReactNode;
}

export declare function Field(props: FieldProps): JSX.Element;
