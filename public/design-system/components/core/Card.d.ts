import * as React from "react";

/**
 * White surface, hairline border, 10px radius, soft shadow.
 * @startingPoint section="Core" subtitle="The standard Harpy container" viewport="700x200"
 */
export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Hover lifts border + shadow. @default false */
  interactive?: boolean;
  /** "flat" drops the shadow; "sunken" is a borderless ink-100 well. @default "default" */
  variant?: "default" | "flat" | "sunken";
  children?: React.ReactNode;
}

export declare function Card(props: CardProps): JSX.Element;
