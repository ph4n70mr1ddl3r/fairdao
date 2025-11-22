import React from 'react';
import { Hero } from '../components/landing/Hero';
import { StatsTicker } from '../components/landing/StatsTicker';
import { ValueProps } from '../components/landing/ValueProps';

export function LandingPage() {
    return (
        <div className="animate-fade-in">
            <Hero />
            <StatsTicker />
            <ValueProps />
        </div>
    );
}
