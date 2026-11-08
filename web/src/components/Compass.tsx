// North arrow drawn in ink: two rings and four points, north filled. It turns
// with the map: pass the map's bearing in degrees and the arrow keeps pointing
// at north. Give it onReset to make it a button that straightens the map.
export function Compass({
  size = 104,
  bearing = 0,
  onReset,
  className,
}: {
  size?: number;
  bearing?: number;
  onReset?: () => void;
  className?: string;
}) {
  const art = (
    <svg
      width={size}
      height={(size * 114) / 104}
      viewBox="-52 -62 104 114"
      role="img"
      aria-label="North arrow"
      style={{ transform: `rotate(${-bearing}deg)`, transformOrigin: "50% 54.4%" }}
    >
      <circle r="36" fill="none" stroke="var(--ink)" strokeWidth="0.75" />
      <circle r="29" fill="var(--paper)" stroke="var(--ink)" strokeWidth="1.5" />
      <path d="M0 -46 L6 -6 L0 0 L-6 -6 Z" fill="var(--route)" />
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

  if (!onReset) return <div className={className}>{art}</div>;
  return (
    <button
      type="button"
      onClick={onReset}
      aria-label="Point the map north"
      className={`${className ?? ""} cursor-pointer`}
    >
      {art}
    </button>
  );
}
