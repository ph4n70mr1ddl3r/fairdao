import React from 'react';
import { TrendingUp } from 'lucide-react';

export function LiquidityChart() {
    return (
        <div className="bg-fair-card border border-white/5 rounded-3xl p-8">
            <h2 className="text-2xl font-bold mb-6 flex items-center gap-2">
                <TrendingUp className="w-6 h-6 text-fair-secondary" />
                AMM Liquidity
            </h2>

            <div className="h-48 flex items-end justify-between gap-2 px-4 border-b border-white/5 pb-4">
                {/* Mock Chart Bars */}
                {[40, 60, 45, 70, 65, 85, 80, 95, 100].map((height, i) => (
                    <div
                        key={i}
                        className="w-full bg-gradient-to-t from-fair-secondary/20 to-fair-secondary/80 rounded-t-sm hover:opacity-80 transition-opacity"
                        style={{ height: `${height}%` }}
                    />
                ))}
            </div>

            <div className="flex justify-between mt-4 text-sm text-fair-muted">
                <span>Price: 0.00042 ETH</span>
                <span>TVL: 1,240 ETH</span>
            </div>
        </div>
    );
}
