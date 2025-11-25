import React from 'react';
import { HouseRepresentative } from '../types';

interface HouseCarouselProps {
  representatives?: HouseRepresentative[];
  previewLimit?: number;
  onViewAll?: () => void;
  actionLabel?: string;
}

const HouseCarousel: React.FC<HouseCarouselProps> = ({
  representatives = [],
  previewLimit = 5,
  onViewAll,
  actionLabel,
}) => {
  const previewRepresentatives = representatives.slice(0, previewLimit);
  const hasMoreRepresentatives = representatives.length > previewLimit;
  const carouselRef = React.useRef<HTMLDivElement>(null);

  React.useLayoutEffect(() => {
    if (carouselRef.current) {
      carouselRef.current.scrollLeft = 0;
    }
  }, [representatives, previewRepresentatives.length]);

  if (!representatives.length) {
    return <p className="text-sm text-muted">House delegation data pending.</p>;
  }

  return (
    <div className="relative">
      <div className="overflow-x-auto pb-4" ref={carouselRef}>
        <div className="flex gap-4 min-h-[220px] min-w-full w-max">
          {previewRepresentatives.map((rep) => {
            const photo = rep.photoLocalPath || rep.photoUrl;
            const districtLabel = rep.isDelegate
              ? `${rep.district || 'Delegate'} Delegate`
              : rep.isAtLarge
                ? 'At-Large'
                : rep.district
                  ? `${rep.district} District`
                  : 'District';
            const partyLabel = rep.partyName || rep.party;
            const infoParts = [districtLabel, partyLabel].filter(Boolean);
            return (
              <article
                key={rep.slug || rep.bioguideId || rep.name}
                className="flex flex-col items-center text-center gap-2 px-3 py-4 rounded-xl border border-soft bg-panel flex-shrink-0 w-48"
              >
                <div className="w-24 h-24 rounded-lg bg-gray-100 dark:bg-gray-800 overflow-hidden flex items-center justify-center text-base font-semibold text-gray-500">
                  {photo ? (
                    <img src={photo} alt={rep.name} className="object-cover w-full h-full" />
                  ) : (
                    rep.name
                      .split(/\s+/)
                      .slice(0, 2)
                      .map((part) => part[0])
                      .join('')
                      .toUpperCase()
                  )}
                </div>
                <div className="space-y-1 self-stretch text-center">
                  <div className="text-sm font-semibold leading-tight">{rep.name}</div>
                  <div className="text-xs text-muted">{infoParts.join(' • ')}</div>
                  {rep.hometown && (
                    <div className="text-xs text-muted">Hometown: {rep.hometown}</div>
                  )}
                  {rep.phone && (
                    <div className="text-xs text-muted">
                      Phone:{' '}
                      <a href={`tel:${rep.phone}`} className="hover:underline">
                        {rep.phone}
                      </a>
                    </div>
                  )}
                </div>
                <div className="flex flex-col items-center gap-2 mt-auto w-full">
                  {rep.website && (
                    <a
                      href={rep.website}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center justify-center text-xs px-4 py-1 rounded bg-[hsl(var(--color-primary))] text-white shadow-sm hover:opacity-90 transition-colors min-w-[120px]"
                    >
                      Official Site
                    </a>
                  )}
                  {rep.profileUrl && (
                    <a
                      href={rep.profileUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center justify-center text-xs px-4 py-1 rounded border border-soft bg-surface hover:bg-panel min-w-[120px]"
                    >
                      Clerk Profile
                    </a>
                  )}
                </div>
              </article>
            );
          })}
          {hasMoreRepresentatives && onViewAll && (
            <button
              type="button"
              onClick={onViewAll}
              className="flex flex-col items-center justify-center text-center gap-2 px-3 py-4 rounded-xl border border-dashed border-[hsl(var(--color-primary))] text-primary bg-primary-soft flex-shrink-0 w-48"
            >
              <div className="text-2xl font-semibold">
                +{representatives.length - previewRepresentatives.length}
              </div>
              <p className="text-sm font-medium">{actionLabel || 'View all House Representatives'}</p>
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

export default HouseCarousel;
