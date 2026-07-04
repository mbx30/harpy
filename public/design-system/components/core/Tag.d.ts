import * as React from "react";

/** Bordered pill chip, optionally removable. */
export interface TagProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Renders a remove (×) button when provided. */
  onRemove?: (e: React.MouseEvent) => void;
  children?: React.ReactNode;
}

export declare function Tag(props: TagProps): JSX.Element;
