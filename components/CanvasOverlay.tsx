import React, { useEffect, useMemo, useRef } from 'react';
import * as d3 from 'd3';

interface CanvasOverlayProps {
  width: number;
  height: number;
  paths: string[];
  transform: d3.ZoomTransform;
  stroke?: string;
  strokeWidth?: number; // in screen pixels (non-scaling)
  lineCap?: CanvasLineCap;
  // Optional local transform applied after the map transform (for AK/HI insets)
  insetScale?: number;
  insetTx?: number;
  insetTy?: number;
}

/**
 * CanvasOverlay
 * Renders many overlay SVG paths efficiently using Canvas + Path2D.
 *
 * Notes:
 * - We apply ctx.setTransform(k, 0, 0, k, x, y) to match the SVG <g transform>.
 * - To emulate vector-effect: non-scaling-stroke, we divide lineWidth by k.
 * - The canvas is expected to be absolutely positioned over the SVG with the same width/height.
 */
const CanvasOverlay: React.FC<CanvasOverlayProps> = ({
  width,
  height,
  paths,
  transform,
  stroke = '#60a5fa',
  strokeWidth = 0.5,
  lineCap = 'round',
  insetScale,
  insetTx,
  insetTy,
}) => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  // Cache Path2D objects so we don't re-parse the path strings on each draw
  const pathObjs = useMemo(() => {
    return paths.map((d) => new Path2D(d));
  }, [paths]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Compute device pixel ratio and display size to align with SVG rendering
    const dpr = (window.devicePixelRatio || 1);
    const rect = canvas.getBoundingClientRect();
  const displayW = Math.max(1, rect.width);
  const displayH = Math.max(1, rect.height);
    // Resize the backing store to match display size * dpr for crispness
    const targetW = Math.max(1, Math.floor(displayW * dpr));
    const targetH = Math.max(1, Math.floor(displayH * dpr));
    if (canvas.width !== targetW || canvas.height !== targetH) {
      canvas.width = targetW;
      canvas.height = targetH;
    }

    // Clear then draw using the current zoom transform
    ctx.save();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, canvas.width, canvas.height);

  // Map atlas units to CSS pixels with preserveAspectRatio='xMidYMid meet'
  const scale = Math.min(displayW / width, displayH / height);
  const offsetX = (displayW - width * scale) / 2;
  const offsetY = (displayH - height * scale) / 2;
  ctx.setTransform(dpr * scale, 0, 0, dpr * scale, dpr * offsetX, dpr * offsetY);

    // Apply map zoom/pan (in atlas units)
    ctx.transform(transform.k, 0, 0, transform.k, transform.x, transform.y);

    // Optional inset transform for AK/HI
    if (insetScale && (insetTx !== undefined) && (insetTy !== undefined)) {
      ctx.transform(insetScale, 0, 0, insetScale, insetTx, insetTy);
    }

  // Keep stroke visually constant in CSS px: compensate for zoom (k) and pre-scale
  ctx.lineWidth = Math.max(0.25, (strokeWidth * dpr) / ((transform.k || 1) * scale));
    ctx.strokeStyle = stroke;
    ctx.lineCap = lineCap;
    ctx.fillStyle = 'transparent';

    for (const p of pathObjs) {
      ctx.stroke(p);
    }

    ctx.restore();
  }, [width, height, pathObjs, transform, stroke, strokeWidth, lineCap]);

  return (
    <canvas
      ref={canvasRef}
      width={width}
      height={height}
      className="absolute inset-0 w-full h-full pointer-events-none"
      aria-hidden
    />
  );
};

export default React.memo(CanvasOverlay);
