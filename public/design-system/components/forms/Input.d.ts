import * as React from "react";

/** Single-line text input. */
export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  /** Leading icon node (16px). */
  icon?: React.ReactNode;
  /** Error styling + aria-invalid. @default false */
  invalid?: boolean;
  /** Geist Mono — for hashes and data values. @default false */
  mono?: boolean;
}

export declare function Input(props: InputProps): JSX.Element;
