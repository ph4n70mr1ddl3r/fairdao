import React from 'react';
import { ArrowRight, FileText } from 'lucide-react';
import { useAccount } from 'wagmi';
import { ConnectButton } from '@rainbow-me/rainbowkit';

export function Hero() {
    const { isConnected } = useAccount();

    return (
        <section className="flex flex-col items-center justify-center text-center py-20 relative z-10">
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-fair-card border border-white/10 mb-8 animate-fade-in">
                <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
                <span className="text-sm text-fair-muted">FairDAO Protocol v0.1</span>
            </div>

            <h1 className="text-6xl md:text-7xl font-bold mb-6 tracking-tight">
                <span className="bg-gradient-to-r from-white via-fair-text to-fair-muted bg-clip-text text-transparent">
                    Fair Token Distribution
                </span>
                <br />
                <span className="bg-gradient-to-r from-fair-primary to-fair-secondary bg-clip-text text-transparent">
                    & Permanent Liquidity
                </span>
            </h1>

            <p className="text-xl text-fair-muted max-w-2xl mb-10 leading-relaxed">
                A Sybil-resistant, community-owned protocol.
                <br />
                64.8M whitelisted addresses. 100% fair launch. No VC premine.
            </p>

            <div className="flex flex-col sm:flex-row gap-4">
                {isConnected ? (
                    <button className="px-8 py-4 rounded-xl bg-fair-primary text-fair-bg font-bold hover:bg-cyan-400 transition-all shadow-[0_0_20px_rgba(0,240,255,0.3)] flex items-center gap-2">
                        Go to Dashboard <ArrowRight className="w-5 h-5" />
                    </button>
                ) : (
                    <ConnectButton.Custom>
                        {({ openConnectModal }) => (
                            <button
                                onClick={openConnectModal}
                                className="px-8 py-4 rounded-xl bg-fair-primary text-fair-bg font-bold hover:bg-cyan-400 transition-all shadow-[0_0_20px_rgba(0,240,255,0.3)] flex items-center gap-2"
                            >
                                Check Eligibility <ArrowRight className="w-5 h-5" />
                            </button>
                        )}
                    </ConnectButton.Custom>
                )}

                <button className="px-8 py-4 rounded-xl bg-fair-card border border-white/10 hover:bg-white/5 transition-all flex items-center gap-2">
                    <FileText className="w-5 h-5" /> Read Whitepaper
                </button>
            </div>
        </section>
    );
}
