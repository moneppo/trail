// North arrow drawn in ink: two rings and four points, north filled.
export function Compass({ size = 104, className }: { size?: number; className?: string }) {
  return (
    <svg
      width={size}
      height={(size * 114) / 104}
      viewBox="-52 -62 104 114"
      role="img"
      aria-label="North arrow"
      className={className}
    >
      <circle r="36" fill="none" stroke="var(--ink)" strokeWidth="0.75" />
      <circle r="29" fill="var(--paper)" stroke="var(--ink)" strokeWidth="1.5" />
      <path d="M0 -46 L6 -6 L0 0 L-6 -6 Z" fill="var(--ink)" />
      <g fill="none" stroke="var(--ink)" strokeWidth="1.5" strokeLinejoin="round">
        <path d="M0 46 L6 6 L0 0 L-6 6 Z" />
        <path d="M-46 0 L-6 -6 L0 0 L-6 6 Z" />
        <path d="M46 0 L6 -6 L0 0 L6 6 Z" />
      </g>
      <text
        x="0"
        y="-49"
        textAnchor="middle"
        fill="var(--ink)"
        style={{ font: "600 12px var(--ff-data)", letterSpacing: "0.14em" }}
      >
        N
      </text>
    </svg>
  );
}
