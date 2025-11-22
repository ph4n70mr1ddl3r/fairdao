import React from 'react';
import { DashboardLayout } from '../components/dashboard/DashboardLayout';
import { ClaimCard } from '../components/dashboard/ClaimCard';
import { ReferralTree } from '../components/dashboard/ReferralTree';
import { LiquidityChart } from '../components/dashboard/LiquidityChart';

export function DashboardPage() {
    return (
        <DashboardLayout>
            <div className="animate-fade-in">
                <ClaimCard />
                <div className="grid md:grid-cols-2 gap-8">
                    <ReferralTree />
                    <LiquidityChart />
                </div>
            </div>
        </DashboardLayout>
    );
}
