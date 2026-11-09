// The small set of line icons Trail uses: thin round-capped strokes on a
// 24-unit square, in the current text color.
import type { ReactNode } from "react";

function Icon({ children, size = 22 }: { children: ReactNode; size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.6"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {children}
    </svg>
  );
}

export const BackIcon = () => (
  <Icon>
    <path d="M14.5 5 L7.5 12 L14.5 19" />
  </Icon>
);

export const InfoIcon = () => (
  <Icon>
    <circle cx="12" cy="12" r="9" />
    <path d="M12 11 V16.5" />
    <circle cx="12" cy="7.8" r="1.1" fill="currentColor" stroke="none" />
  </Icon>
);

export const PersonIcon = () => (
  <Icon>
    <circle cx="12" cy="8.2" r="3.8" />
    <path d="M4.8 20 C4.8 15.4 8 13.4 12 13.4 C16 13.4 19.2 15.4 19.2 20" />
  </Icon>
);

export const SunIcon = () => (
  <Icon>
    <circle cx="12" cy="12" r="4" />
    {[0, 45, 90, 135, 180, 225, 270, 315].map((deg) => (
      <path key={deg} d="M12 3 V5.5" transform={`rotate(${deg} 12 12)`} />
    ))}
  </Icon>
);

export const MoonIcon = () => (
  <Icon>
    <path d="M19.5 14.5 A8 8 0 1 1 9.5 4.5 A6.5 6.5 0 0 0 19.5 14.5 Z" />
  </Icon>
);

/** A circle with its right half filled: follows the device, light or dark. */
export const DeviceIcon = () => (
  <Icon>
    <circle cx="12" cy="12" r="8" />
    <path d="M12 4 A8 8 0 0 1 12 20 Z" fill="currentColor" />
  </Icon>
);
