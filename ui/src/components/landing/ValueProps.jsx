import React from 'react';
import { ShieldCheck, Users, Zap } from 'lucide-react';

const features = [
    {
        icon: ShieldCheck,
        title: 'Sybil Resistant',
        description: 'Based on historical Ethereum activity (gas spent). No retroactive farming possible.'
    },
    {
        icon: Users,
        title: 'Community Owned',
        description: 'Zero premine. No team allocation. 100% of tokens are distributed to the community.'
    },
    {
        icon: Zap,
        title: 'Permanent Liquidity',
        description: 'Innovative AMM design ensures liquidity grows with every claim and cannot be withdrawn.'
    }
];

export function ValueProps() {
    return (
        <section className="grid md:grid-cols-3 gap-8 max-w-6xl mx-auto mb-20">
            {features.map((feature, index) => (
                <div key={index} className="p-8 rounded-3xl bg-fair-card border border-white/5 hover:bg-white/5 transition-all group">
                    <div className="w-12 h-12 rounded-xl bg-fair-primary/10 flex items-center justify-center mb-6 group-hover:bg-fair-primary/20 transition-colors">
                        <feature.icon className="w-6 h-6 text-fair-primary" />
                    </div>
                    <h3 className="text-xl font-bold mb-3">{feature.title}</h3>
                    <p className="text-fair-muted leading-relaxed">
                        {feature.description}
                    </p>
                </div>
            ))}
        </section>
    );
}
