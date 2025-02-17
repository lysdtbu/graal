/*
 * Copyright (c) 2013, 2022, Oracle and/or its affiliates. All rights reserved.
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
 *
 * This code is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 only, as
 * published by the Free Software Foundation.  Oracle designates this
 * particular file as subject to the "Classpath" exception as provided
 * by Oracle in the LICENSE file that accompanied this code.
 *
 * This code is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * version 2 for more details (a copy is included in the LICENSE file that
 * accompanied this code).
 *
 * You should have received a copy of the GNU General Public License version
 * 2 along with this work; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
 * or visit www.oracle.com if you need additional information or have any
 * questions.
 */
package jdk.graal.compiler.nodes;

import static jdk.graal.compiler.nodeinfo.InputType.State;
import static jdk.graal.compiler.nodeinfo.NodeCycles.CYCLES_0;
import static jdk.graal.compiler.nodeinfo.NodeSize.SIZE_0;

import jdk.graal.compiler.core.common.type.StampFactory;
import jdk.graal.compiler.graph.NodeClass;
import jdk.graal.compiler.nodes.spi.LIRLowerable;
import jdk.graal.compiler.nodes.spi.NodeLIRBuilderTool;
import jdk.graal.compiler.nodes.spi.NodeWithState;
import jdk.graal.compiler.nodes.spi.Simplifiable;
import jdk.graal.compiler.nodes.spi.SimplifierTool;
import jdk.graal.compiler.nodeinfo.NodeInfo;

import jdk.vm.ci.code.site.InfopointReason;

/**
 * Nodes of this type are inserted into the graph to denote points of interest to debugging.
 */
@NodeInfo(cycles = CYCLES_0, size = SIZE_0)
public final class FullInfopointNode extends FixedWithNextNode implements LIRLowerable, NodeWithState, Simplifiable {
    public static final NodeClass<FullInfopointNode> TYPE = NodeClass.create(FullInfopointNode.class);
    protected final InfopointReason reason;
    @Input(State) FrameState state;
    @OptionalInput ValueNode escapedReturnValue;

    public FullInfopointNode(InfopointReason reason, FrameState state, ValueNode escapedReturnValue) {
        super(TYPE, StampFactory.forVoid());
        this.reason = reason;
        this.state = state;
        this.escapedReturnValue = escapedReturnValue;
    }

    public InfopointReason getReason() {
        return reason;
    }

    private void setEscapedReturnValue(ValueNode x) {
        updateUsages(escapedReturnValue, x);
        escapedReturnValue = x;
    }

    @Override
    public void simplify(SimplifierTool tool) {
        if (escapedReturnValue != null && state != null && state.outerFrameState() != null) {
            ValueNode returnValue = escapedReturnValue;
            setEscapedReturnValue(null);
            tool.removeIfUnused(returnValue);
        }
    }

    @Override
    public void generate(NodeLIRBuilderTool generator) {
        generator.visitFullInfopointNode(this);
    }

    public FrameState getState() {
        return state;
    }

    @Override
    public boolean verify() {
        return state != null && super.verify();
    }

}
