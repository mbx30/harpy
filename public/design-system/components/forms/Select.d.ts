import * as React from "react";

/** Styled native select with a Lucide chevron. */
export interface SelectProps extends React.SelectHTMLAttributes<HTMLSelectElement> {
  /** <option> elements. */
  children?: React.ReactNode;
}

export declare function Select(props: SelectProps): JSX.Element;
