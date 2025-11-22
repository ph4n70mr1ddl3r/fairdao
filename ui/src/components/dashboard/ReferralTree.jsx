import React from 'react';
import { User, Plus } from 'lucide-react';

export function ReferralTree() {
    return (
        <div className="bg-fair-card border border-white/5 rounded-3xl p-8 mb-8">
            <div className="flex items-center justify-between mb-8">
                <h2 className="text-2xl font-bold">Referral Forest</h2>
                <button className="px-4 py-2 rounded-lg bg-white/5 hover:bg-white/10 text-sm font-medium transition-colors">
                    Generate Invite Link
                </button>
            </div>

            <div className="flex flex-col items-center">
                {/* Root (You) */}
                <div className="flex flex-col items-center mb-8 relative z-10">
                    <div className="w-16 h-16 rounded-full bg-fair-primary text-fair-bg flex items-center justify-center shadow-[0_0_20px_rgba(0,240,255,0.3)]">
                        <User className="w-8 h-8" />
                    </div>
                    <div className="mt-2 font-medium text-fair-primary">You</div>
                </div>

                {/* Connector Lines */}
                <div className="w-full max-w-md h-8 border-t-2 border-r-2 border-l-2 border-white/10 rounded-t-2xl mb-4 relative -mt-4" />

                {/* Children Nodes */}
                <div className="flex justify-between w-full max-w-md gap-4">
                    {[1, 2, 3, 4].map((slot) => (
                        <div key={slot} className="flex flex-col items-center group cursor-pointer">
                            <div className="w-12 h-12 rounded-full bg-white/5 border border-white/10 flex items-center justify-center group-hover:border-fair-primary/50 transition-colors">
                                <Plus className="w-5 h-5 text-fair-muted group-hover:text-fair-primary" />
                            </div>
                            <div className="mt-2 text-xs text-fair-muted">Empty</div>
                        </div>
                    ))}
                </div>
            </div>
        </div>
    );
}
