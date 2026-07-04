import * as React from "react";

/** Modal dialog: charcoal scrim (no blur), card at overlay shadow. */
export interface DialogProps extends React.HTMLAttributes<HTMLDivElement> {
  open: boolean;
  /** Called on scrim click and the × button. Omit to force a footer action. */
  onClose?: () => void;
  title: string;
  /** Action row, right-aligned (Buttons). */
  footer?: React.ReactNode;
  children?: React.ReactNode;
}

export declare function Dialog(props: DialogProps): JSX.Element | null;
