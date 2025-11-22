import React from 'react';
import { CheckCircle, AlertCircle } from 'lucide-react';

export function ClaimCard() {
    // Mock state for now
    const isEligible = true;
    const hasClaimed = false;

    return (
        <div className="bg-fair-card border border-white/5 rounded-3xl p-8 mb-8 relative overflow-hidden">
            <div className="absolute top-0 right-0 w-64 h-64 bg-fair-primary/5 rounded-full blur-[64px] pointer-events-none" />

            <div className="relative z-10">
                <h2 className="text-2xl font-bold mb-6 flex items-center gap-3">
                    Claim Status
                    {isEligible && <span className="text-xs bg-green-500/20 text-green-400 px-2 py-1 rounded-full border border-green-500/20">Eligible</span>}
                </h2>

                <div className="flex flex-col md:flex-row items-center justify-between gap-8">
                    <div>
                        <div className="text-fair-muted mb-1">Available to Claim</div>
                        <div className="text-5xl font-bold text-white mb-4">100 FAIR</div>
                        <div className="flex items-center gap-2 text-sm text-green-400">
                            <CheckCircle className="w-4 h-4" />
                            Verified via Historical Gas Usage
                        </div>
                    </div>

                    <button
                        disabled={hasClaimed}
                        className="w-full md:w-auto px-8 py-4 rounded-xl bg-fair-primary text-fair-bg font-bold hover:bg-cyan-400 transition-all shadow-[0_0_20px_rgba(0,240,255,0.3)] disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                        {hasClaimed ? 'Tokens Claimed' : 'Claim Tokens'}
                    </button>
                </div>
            </div>
        </div>
    );
}
