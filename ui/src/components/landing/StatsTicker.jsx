import React from 'react';

const stats = [
    { label: 'Whitelisted Addresses', value: '64.8M' },
    { label: 'FAIR per Claim', value: '100' },
    { label: 'Total Claims', value: '0' }, // Placeholder
    { label: 'Current Liquidity', value: '$0.00' }, // Placeholder
];

export function StatsTicker() {
    return (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 w-full max-w-6xl mx-auto mb-20">
            {stats.map((stat, index) => (
                <div key={index} className="p-6 rounded-2xl bg-fair-card border border-white/5 backdrop-blur-sm text-center hover:border-fair-primary/30 transition-colors">
                    <div className="text-3xl font-bold text-white mb-1">{stat.value}</div>
                    <div className="text-sm text-fair-muted uppercase tracking-wider">{stat.label}</div>
                </div>
            ))}
        </div>
    );
}
