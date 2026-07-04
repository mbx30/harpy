import * as React from "react";

export interface TabItem {
  value: string;
  label: React.ReactNode;
}

/** Underline tab list; amber indicator on the active tab. */
export interface TabsProps extends Omit<React.HTMLAttributes<HTMLDivElement>, "onChange"> {
  tabs: TabItem[];
  /** Controlled active value. */
  value?: string;
  /** Uncontrolled initial value. @default first tab */
  defaultValue?: string;
  onChange?: (value: string) => void;
}

export declare function Tabs(props: TabsProps): JSX.Element;
