import React from 'react';
import { LayoutDashboard, Gift, Users, Vote } from 'lucide-react';

const navItems = [
    { icon: LayoutDashboard, label: 'Overview', active: true },
    { icon: Gift, label: 'Claim', active: false },
    { icon: Users, label: 'Referrals', active: false },
    { icon: Vote, label: 'Governance', active: false },
];

export function DashboardLayout({ children }) {
    return (
        <div className="flex flex-col md:flex-row gap-8 min-h-[calc(100vh-100px)]">
            {/* Sidebar */}
            <aside className="w-full md:w-64 flex-shrink-0">
                <div className="bg-fair-card border border-white/5 rounded-2xl p-4 sticky top-24">
                    <nav className="space-y-2">
                        {navItems.map((item) => (
                            <button
                                key={item.label}
                                className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all ${item.active
                                        ? 'bg-fair-primary/10 text-fair-primary font-medium'
                                        : 'text-fair-muted hover:bg-white/5 hover:text-white'
                                    }`}
                            >
                                <item.icon className="w-5 h-5" />
                                {item.label}
                            </button>
                        ))}
                    </nav>
                </div>
            </aside>

            {/* Main Content */}
            <div className="flex-grow">
                {children}
            </div>
        </div>
    );
}
