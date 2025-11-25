// Example per‑state incremental data file. Only include fields that differ from BASE.
export default {
  name: 'New York',
  last_updated: '2025-01-15',
  government: {
    legislature: { upper_chamber_name: 'Senate', lower_chamber_name: 'Assembly' },
    branches: [
      { name: 'Executive', details: 'Headed by the Governor.' }
    ]
  },
  federal_representation: {
    senators: [
      { name: 'Kirsten Gillibrand', party: 'D' },
      { name: 'Chuck Schumer', party: 'D' }
    ],
    house_districts: 26
  },
  resources: [
    { label: 'Register to Vote', url: 'https://voterreg.dmv.ny.gov/' }
  ],
  sources: [
    { label: 'Official State Website', url: 'https://www.ny.gov' }
  ]
};
